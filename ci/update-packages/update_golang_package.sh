#!/bin/bash

set -e

echo "${PRIVATE_YAML}" > $PWD/capi-release/config/private.yml

pushd golang-release
  new_go_version=$(bosh blobs | grep linux | grep go${GO_VERSION} | cut -d . -f 1-3 | sort | tail -1)
popd

cd capi-release

bosh vendor-package golang-${GO_VERSION}-linux ../golang-release

git --no-pager diff packages .final_builds

git config user.name "ari-wg-gitbot"
git config user.email "app-runtime-interfaces@cloudfoundry.org"

git add -A packages .final_builds
git commit -n --allow-empty -m "Bump Golang to $new_go_version"
cp -r $PWD/. ../updated-capi-release
