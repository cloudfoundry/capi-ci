# capi-ci

Hello, this is the CAPI team's CI repo. It houses Concourse configuration settings for our CI environments.

Check it out! https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/teams/capi-team/pipelines/capi

:pushpin: This repository has gone through a complete overhaul. The old artifacts can still be found on the [legacy branch](https://github.com/cloudfoundry/capi-ci/tree/legacy).

## Environments

See [pipeline.yml](https://github.com/cloudfoundry/capi-ci/blob/main/ci/pipeline.yml) for more details.

All environments are short-lived. The webserver is now "Puma" for all environments.
```
   ________________________________________________________________________
 / \                                                                       \
|   |  Elsa: biggest and most "real" environment                           |
 \_ |          · HA / Multi-AZ                                             |
    |          · Windows cell                                              |
    |          · Encrypted database                                        |
    |          · Clustered database                                        |
    |          · Runtime CredHub (assisted mode)                           |
    |          · Database: MySQL                                           |
    |          · Platform: GCP                                             |
    |          · Blobstore: GCP blobstore                                  |
    |                                                                      |
    |  Kiki: used for testing that db migrations are backwards compatible  |
    |          · Database: PostgreSQL                                      |
    |          · Platform: GCP                                             |
    |          · Blobstore: WebDAV                                         |
    |                                                                      |
    |  Asha: used for testing CATS and CAPI-BARA tests on MySQL            |
    |          · Database: MySQL                                           |
    |          · Platform: GCP                                             |
    |          · Blobstore: WebDAV                                         |
    |                                                                      |
    |  Olaf: used for running CATS and CAPI-BARA tests on AWS with MySQL   |
    |          · Database: MySQL                                           |
    |          · Platform: AWS                                             |
    |          · Blobstore: S3                                             |
    |                                                                      |
    |  Scar: used for testing CATS and CAPI-BARA tests on PostgreSQL       |
    |          · Database: PostgreSQL                                      |
    |          · Platform: GCP                                             |
    |          · Blobstore: WebDAV                                         |
    |                                                                      |
    |  Gyro: used for testing experimental features on GCP / PostgreSQL    |
    |          · Database: PostgreSQL                                      |
    |          · Platform: GCP                                             |
    |          · Blobstore: WebDAV                                         |
    |   ___________________________________________________________________|___
    |  /                                                                      /
    \_/______________________________________________________________________/
```

### What's Up with Kiki

Kiki starts with an older version of cf-deployment. It then runs the new migrations, but keeps the old Cloud Controller code. This catches any backwards-incompatible migrations. This is important because Cloud Controller instances do rolling upgrades. For example: if you write a migration that drops a table, old CC instances that depend on that table existing will crash during the rolling deploy.

## Pipelines

### capi

This pipeline is responsible for testing, building, and releasing capi-release. For guidance on releasing CAPI, see [this document](https://github.com/cloudfoundry/capi-release/blob/develop/docs/releasing-capi.md).

#### capi-release

This is where the majority of testing for capi-release components live.

- Runs unit tests for Cloud Controller and bridge components
- Builds capi-release release candidates and deploys to Elsa, Kiki, Asha, Olaf, and Scar
- Runs appropriate integration tests for each environment
- Bumps the `ci-passed` branch of capi-release
- Updates release candidate in v3 docs every time `ci-passed` branch is updated.

#### bump-dependencies

Automatically bumps golang version for capi-release components every time a new [golang-release](https://github.com/bosh-packages/golang-release) is available. Also bumps Valkey and nginx.

#### ship-it

Jobs responsible for cutting a capi-release.

- Bump API versions
- Update API docs
- Release capi-release

#### bbl-up

Updates the bosh deployments for all the pipeline environments (using `bbl up`).

#### bbl-destroy

Theoretically useful for destroying broken bosh deployments for all the pipeline environments. Often doesn't work because the directors are in such bad state. There are also jobs to manually release pool resources for the following environments: Elsa, Asha, and Scar.

### bosh-lites

Pipeline responsible for managing the development [bosh-lite pool](https://github.com/cloudfoundry/capi-env-pool/).

- Create new bosh-lites if there is room in the pool
- Delete released bosh-lites

### cert-rotation

Automatic certificate rotation for the long-lived environments (currently only Elsa). The goal is to prevent certificate expiration. The jobs perform a three-step CA certificate rotation according to the [CredHub CA Rotation documentation](https://github.com/pivotal/credhub-release/blob/main/docs/ca-rotation.md). The list of CA certificates is hard-coded in the [rotate_steps.yml task](./ci/rotate-certs/rotate_steps.yml). When a new CA certificate is added or deleted from cf-deployment, the list needs to be updated. Each job of the pipeline is idempotent and can be retriggered in case of a failure. Note however that the order of the jobs must be preserved in case of manual intervention.

**Note**: Do not make the pipeline "public" in Concourse as the log shows sensitive data!

Should the rotation fail unexpectedly, you can inspect the current certificate state with the CredHub API:
```
credhub curl -p "/api/v1/certificates?name=/elsa-ha/cf/<certificate name>"
```
This command shows the certificate metadata and all certificate versions. For CA certificates, the list of signed certificates is shown which is used in the 2nd step to regenerate the child certificats. The certificate versions also contain the "transitional" flag which is created, moved and deleted in steps 1, 2 and 3, respectively.

If the certificate state is broken and cannot be repaired, the deployment and its credentials can be deleted with `bosh -d cf delete-deployment`. The next run of job "elsa-ha-deploy-cf" will redeploy CF from scratch.

#### Using Pooled Environments

There are a number of helpful scripts in [capi-workspace](https://github.com/cloudfoundry/capi-workspace) for using the bosh-lite pool. Most notably, `claim_bosh_lite`, `unclaim_bosh_lite`, and `print_env_info`. See [the commands list](https://github.com/cloudfoundry/capi-workspace#capi-commands) for a full list of useful commands for interacting with the pool.
