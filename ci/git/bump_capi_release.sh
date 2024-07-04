#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

pushd cloud_controller_ng
  SOURCE_MASTER_SHA=$(git rev-parse HEAD)
popd

pushd cc-uploader
  CC_UPLOADER_SHA=$(git rev-parse HEAD)
popd

pushd tps
  TPS_SHA=$(git rev-parse HEAD)
popd

pushd capi-release
  pushd src/cloud_controller_ng
    git fetch
    git checkout $SOURCE_MASTER_SHA
  popd

  pushd src/code.cloudfoundry.org
    pushd cc-uploader
      git fetch
      git checkout "${CC_UPLOADER_SHA}"
    popd

    pushd tps
      git fetch
      git checkout "${TPS_SHA}"
    popd
  popd

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

    "$SCRIPT_DIR/staged_shortlog.rb"
    "$SCRIPT_DIR/staged_shortlog.rb" | git commit -F -
  fi
popd

cp -r capi-release bumped/capi-release
