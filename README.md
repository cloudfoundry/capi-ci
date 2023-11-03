# capi-ci

Hello, this is the capi team's ci repo. It houses concourse configuration settings for our ci environments.

Check it out! https://ci.cake.capi.land/

## Environments

See [pipeline.yml](https://github.com/cloudfoundry/capi-ci/blob/main/ci/pipeline.yml) for more details (for example: https://github.com/cloudfoundry/capi-ci/blob/8de01d623d0ec99e9be55dec9047668ff77bffd5/ci/pipeline.yml#L2071).

```
   ________________________________________________________________________
 / \                                                                       \
|   |                                                                      |
 \_ |  Elsa: biggest and most "real" environment                           |
    |          · Long-lived                                                |
    |          · HA / Multi-AZ                                             |
    |          · Windows cell                                              |
    |          · "Real" router certs (via DigiCert)                        |
    |          · Encrypted database                                        |
    |          · Clustered database                                        |
    |          · Runtime credhub (assisted mode)                           |
    |          · Telemetry                                                 |
    |          · Database: MySQL                                           |
    |          · Blobstore: S3                                             |
    |                                                                      |
    |  Mulan: used for testing Postgres and non-standard configuration     |
    |          · Long-lived                                                |
    |          · Runtime credhub (non-assisted mode)                       |
    |          · Database: Postgres                                        |
    |          · Blobstore: WebDAV                                         |
    |                                                                      |
    |  Ripley: used for testing NFS blobstore                              |
    |          · Long-lived                                                |
    |          · Database: MySQL                                           |
    |          · Blobstore: NFS                                            |
    |                                                                      |
    |  Leia: used for testing Azure blobstore                              |
    |          · Long-lived                                                |
    |          · Database: MySQL                                           |
    |          · Blobstore: Azure                                          |
    |                                                                      |
    |  Rey: used for testing GCP blobstore                                 |
    |          · Long-lived                                                |
    |          · Database: MySQL                                           |
    |          · Blobstore: GCP                                            |
    |                                                                      |
    |  Kiki: used for testing that db migrations are backwards compatible  |
    |          · Short-lived                                               |
    |          · Database: MySQL                                           |
    |          · Blobstore: WebDAV                                         |
    |                                                                      |
    |  Xena: used for testing BBR on MySQL                                 |
    |          · Short-lived                                               |
    |          · Database: MySQL                                           |
    |          · Blobstore: WebDAV                                         |
    |                                                                      |
    |  Gabrielle: used for testing BBR on Postgres                         |
    |          · Short-lived                                               |
    |          · Database: Postgres                                        |
    |          · Blobstore: WebDAV                                         |
    |                                                                      |
    |                                                                      |    
    |   ___________________________________________________________________|___
    |  /                                                                      /
    \_/______________________________________________________________________/
```

### Variables

- Database: https://docs.cloudfoundry.org/concepts/architecture/cloud-controller.html#database
- Blobstore: https://docs.cloudfoundry.org/deploying/common/cc-blobstore-config.html
- HA: https://docs.cloudfoundry.org/concepts/high-availability.html
- Short-lived/Long-lived: Short-lived environments are destroyed and re-deployed every test run. Long-lived ones are not torn down between runs.
- DB Encryption: https://docs.cloudfoundry.org/adminguide/encrypting-cc-db.html
- Clustered DB: https://docs.pivotal.io/application-service/2-9/mysql/scaling-mysql.html
- Runtime Credhub: https://docs.pivotal.io/application-service/2-10/operating/secure-si-creds.html
- Windows Cells: https://docs.cloudfoundry.org/deploying/cf-deployment/deploy-cf.html#ops-files
- Telemetry: https://docs.pivotal.io/telemetry-collector/0-5/index.html
- Certs: https://docs.cloudfoundry.org/adminguide/securing-traffic.html (CATs etc are actually validating SSL certs (no `--skip-ssl-validation`))

### What's Up with Kiki

Kiki starts with an older version of cf-deployment. It then runs the new migrations, but keeps the old cloud controller code. This catches any backwards-incompatible migrations. This is important because cloud controller instances do rolling upgrades. For example: if you write a migration that drops a table, old CC instances that depend on that table existing will crash during the rolling deploy.


## Pipelines

### capi

This pipeline is responsible for testing, building, and releasing capi-release.

#### capi-release

This is where the majority of testing for capi-release components live.

- Runs unit tests for Cloud Controller and bridge components
- Builds capi-release release candidates and deploys to Elsa, Ripley, Mulan, Kiki, Xena, and Gabrielle 
- Runs appropriate integration tests for each environment
- Bumps the `ci-passed` branch of capi-release

#### blobstore-fanout

Additional blobstore tests that do no block the pipeline. These were removed from the main flow because the backing blobstores were historically flakey. They should be green (or at least not have obviously blobstore-related failures) before cutting a release.

- Deploys to Leia and Rey
- Runs appropriate integration tests

#### ship-it

Jobs responsible for cutting capi-release.

- Bump API versions
- Update API docs
- Release capi-release

#### dependencies-docs

Assortment of jobs for updating docs and other things.

- Update v2 docs every time a new cf-deployment is released
- Update release candidate in v3 docs every time `ci-passed` branch is updated

#### update-bosh

Updates the bosh deployments for all the pipeline environments (using `bbl up`).

#### bbl-destroy

Theoretically useful for destroying broken bosh deployments for all the pipeline environments. Often doesn't work because the directors are in such bad state.

#### rotate-certs

Rotate the bosh-managed certificates for all the pipeline environments every other month. This prevents the certs from expiring and breaking the pipelines.

#### bump-dependencies

Automatically bumps golang version for capi-release components every time a new [golang-release](https://github.com/bosh-packages/golang-release) is available.

### concourse

Pipeline responsible for updating the concourse deployment that it is running on. Meta!

### docker-images

Build the [docker images](https://github.com/cloudfoundry/capi-dockerfiles) that are used by other pipeline jobs. This is where all the dependencies that we need to run unit tests, acceptance tests, bosh deploys, etc come from.

- Bump bosh CLI version in docker files
- Every week rebuild images used for
   - Pushing release candidate docs
   - Running ruby unit tests
   - Running golang unit tests
   - Running DRATS (for testing BBR)
   - Running migration backwards compatibility tests
   - Running SITS (for testing sync job)
   - Deploying pipeline bosh environments
   - Creating releases and other random things (`runtime-ci` tag)
   - Manging the bosh-lite pool

### bosh-lite

Pipeline responsible for managing the development [bosh-lite pool](https://github.com/pivotal-cf/capi-env-pool/).

- Delete released bosh-lites
- Create new bosh-lites if there is room in the pool
- Post in slack every week with what bosh lites are claimed in the pool

### streamline-team

Very important pipeline that randomly selects a person every week and posts about it in slack.
