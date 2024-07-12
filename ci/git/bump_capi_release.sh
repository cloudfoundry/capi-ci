#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

pushd cloud_controller_ng > /dev/null
  SOURCE_MASTER_SHA=$(git rev-parse HEAD)
popd > /dev/null

pushd cc-uploader > /dev/null
  CC_UPLOADER_SHA=$(git rev-parse HEAD)
popd > /dev/null

pushd tps > /dev/null
  TPS_SHA=$(git rev-parse HEAD)
popd > /dev/null

pushd capi-release > /dev/null
  pushd src/cloud_controller_ng > /dev/null
    git fetch
    git checkout $SOURCE_MASTER_SHA
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
popd > /dev/null

cp -r capi-release bumped/capi-release
