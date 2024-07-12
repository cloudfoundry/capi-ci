#!/bin/bash

set -eu

: "${BOSH_DEPLOYMENT_NAME:="cf"}"
: "${BOSH_API_INSTANCE:="api/0"}"

setup_bbl_environment() {
  pushd "capi-ci-private/${BBL_STATE_DIR}" > /dev/null
    eval "$(bbl print-env)"
  popd > /dev/null
}

upload_capi_release_tarball() {
  echo "Uploading capi-release tarball..."

  pushd capi-release-tarball > /dev/null
    ALL_CAPI_REL_TGZS=( capi-*.tgz )
    if [ ${#ALL_CAPI_REL_TGZS[@]} -gt 1 ]; then
      echo "Error: More than one file matches the pattern 'capi-*.tgz'"
      exit 1
    elif [[ ! -e ${ALL_CAPI_REL_TGZS[0]} ]]; then
      echo "Error: No file matches the pattern 'capi-*.tgz'"
      exit 1
    fi

    CAPI_REL_TGZ=${ALL_CAPI_REL_TGZS[0]}
    bosh -d "${BOSH_DEPLOYMENT_NAME}" scp "${CAPI_REL_TGZ}" "${BOSH_API_INSTANCE}:/tmp"
  popd > /dev/null
}

unpack_capi_release_tarball() {
  echo "Unpacking capi-release tarball..."
  bosh ssh -d "${BOSH_DEPLOYMENT_NAME}" "${BOSH_API_INSTANCE}" \
    "cd /tmp; tar -xzf ${CAPI_REL_TGZ} packages/cloud_controller_ng.tgz; cd packages; tar -xzf cloud_controller_ng.tgz"
}

copy_db_migrations() {
  echo "Copying NEW db migrations to OLD deployment..."
  bosh ssh -d "${BOSH_DEPLOYMENT_NAME}" "${BOSH_API_INSTANCE}" \
    "cd /tmp/packages/cloud_controller_ng; sudo cp -r db /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/"
}

run_db_migrations() {
  echo "Applying NEW db migrations..."
  bosh ssh -d "${BOSH_DEPLOYMENT_NAME}" "${BOSH_API_INSTANCE}" \
    "cd /var/vcap/packages/cloud_controller_ng/cloud_controller_ng; source /var/vcap/jobs/cloud_controller_ng/bin/ruby_version.sh; sudo bundle exec rake db:migrate; sudo bundle exec rake db:ensure_migrations_are_current"
}

main() {
  setup_bbl_environment
  upload_capi_release_tarball
  unpack_capi_release_tarball
  copy_db_migrations
  run_db_migrations
}

main
