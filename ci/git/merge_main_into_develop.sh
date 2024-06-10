#!/usr/bin/env bash

set -eu

pushd capi-release
  echo "----- Set git identity"
  git config user.name "ari-wg-gitbot"
  git config user.email "app-runtime-interfaces@cloudfoundry.org"

  echo "----- Adding main cloned release as remote"
  git remote add local-capi-release-main ../capi-release-main
  git fetch local-capi-release-main
  git merge --no-edit local-capi-release-main/main
popd

cp -a capi-release merged/capi-release
