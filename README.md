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
    |          · Encrypted database                                        |
    |          · Clustered database                                        |
    |          · Runtime credhub (assisted mode)                           |
    |          · Database: MySQL                                           |
    |          · Platform: GCP                                             |
    |          · Blobstore: GCP blobstore                                  |
    |                                                                      |
    |                                                                      |
    |  Kiki: used for testing that db migrations are backwards compatible  |
    |          · Short-lived                                               |
    |          · Database: Postgres                                        |
    |          · Platform: GCP                                             |
    |          · Blobstore: WebDAV                                         |
    |                                                                      |
    |  Asha: used for testing CATS and CAPI-BARA tests on MySQL            |
    |          · Short-lived                                               |
    |          · Database: MySQL                                           |
    |          · Platform: GCP                                             |
    |          · Blobstore: WebDAV                                         |
    |                                                                      |
    |  Scar: used for testing CATS and CAPI-BARA tests on PostgreSQL       |
    |          · Short-lived                                               |
    |          · Database: PostgreSQL                                      |
    |          · Platform: GCP                                             |
    |          · Blobstore: WebDAV                                         |
    |                                                                      |
    |                                                                      |    
    |  All other envrionments are not used and might be cleaned up!        |
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
- Clustered DB: https://github.com/cloudfoundry/pxc-release?tab=readme-ov-file#pxc-release
- Runtime Credhub: https://github.com/pivotal-cf/docs-operating-pas/blob/master/secure-si-creds.html.md.erb
- Windows Cells: https://docs.cloudfoundry.org/deploying/cf-deployment/deploy-cf.html#ops-files
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

#### blobstore-fanout (missing currently)

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

#### bbl-up

Updates the bosh deployments for all the pipeline environments (using `bbl up`).

#### bbl-destroy

Theoretically useful for destroying broken bosh deployments for all the pipeline environments. Often doesn't work because the directors are in such bad state.

#### rotate-certs

Rotate the bosh-managed certificates for all the pipeline environments every other month. This prevents the certs from expiring and breaking the pipelines.

#### bump-dependencies

Automatically bumps golang version for capi-release components every time a new [golang-release](https://github.com/bosh-packages/golang-release) is available.

### docker-images (missing currently)

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

Pipeline responsible for managing the development [bosh-lite pool](https://github.com/cloudfoundry/capi-env-pool/).

- Create new bosh-lites if there is room in the pool
- Delete released bosh-lites

 #### Using Pooled Environments

 There are a number of helpful scripts in
 [capi-workspace](https://github.com/cloudfoundry/capi-workspace) for using the
 bosh lite pool. Most notably, `claim_bosh_lite`, `unclaim_bosh_lite`, and
 `print_env_info`. See [the commands
 list](https://github.com/cloudfoundry/capi-workspace?tab=readme-ov-file#capi-commands)
 for a full list of useful commands for interacting with the pool.
