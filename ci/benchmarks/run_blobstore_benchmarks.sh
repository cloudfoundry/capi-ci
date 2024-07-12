#!/bin/bash

set -eu

: "${BOSH_DEPLOYMENT_NAME:="cf"}"
: "${BOSH_API_INSTANCE:="api/0"}"

setup_bbl_environment() {
  pushd "capi-ci-private/${BBL_STATE_DIR}" > /dev/null
    eval "$(bbl print-env)"
  popd > /dev/null
}

perform_blobstore_benchmarks() {
  echo "Performing blobstore benchmarks..."
  bosh ssh -d "${BOSH_DEPLOYMENT_NAME}" "${BOSH_API_INSTANCE}" "sudo /var/vcap/jobs/cloud_controller_ng/bin/perform_blobstore_benchmarks"
}

main() {
  setup_bbl_environment
  perform_blobstore_benchmarks
}

main
