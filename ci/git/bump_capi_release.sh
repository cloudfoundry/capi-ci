#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

pushd cloud_controller_ng > /dev/null
  CCNG_SHA=$(git rev-parse HEAD)
popd > /dev/null

pushd cc-uploader > /dev/null
  CC_UPLOADER_SHA=$(git rev-parse HEAD)
popd > /dev/null

pushd tps > /dev/null
  TPS_SHA=$(git rev-parse HEAD)
popd > /dev/null

pushd blobstore_url_signer > /dev/null
  BLOBSTORE_URL_SIGNER_SHA=$(git rev-parse HEAD)
popd > /dev/null

pushd capi-release > /dev/null
  pushd src/cloud_controller_ng > /dev/null
    git fetch
    git checkout "${CCNG_SHA}"
  popd > /dev/null

  pushd src/code.cloudfoundry.org > /dev/null
    pushd cc-uploader > /dev/null
      git fetch
      git checkout "${CC_UPLOADER_SHA}"
    popd > /dev/null

    pushd tps > /dev/null
      git fetch
      git checkout "${TPS_SHA}"
    popd > /dev/null
  popd > /dev/null

  pushd src/github.com/cloudfoundry/blobstore_url_signer > /dev/null
    git fetch
    git checkout "${BLOBSTORE_URL_SIGNER_SHA}"
  popd > /dev/null

  set +e
    git diff --exit-code
    exit_code=$?
  set -e

  if [[ $exit_code -eq 0 ]]
  then
    echo "There are no changes to commit."
  else
    git config user.name "ari-wg-gitbot"
    git config user.email "app-runtime-interfaces@cloudfoundry.org"

    git add src/cloud_controller_ng
    git add src/code.cloudfoundry.org
    git add src/github.com/cloudfoundry/blobstore_url_signer

    "$SCRIPT_DIR/staged_shortlog.rb"
    "$SCRIPT_DIR/staged_shortlog.rb" | git commit -F -
  fi
popd > /dev/null

cp -r capi-release/. updated-capi-release
