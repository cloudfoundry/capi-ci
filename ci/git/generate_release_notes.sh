#!/usr/bin/env bash

# To test the release notes generations locally, run in this folder:
# git clone --recursive --branch=main https://github.com/cloudfoundry/capi-release.git capi-release-main
# git clone --recursive --branch=develop https://github.com/cloudfoundry/capi-release.git capi-release-ci-passed
# ./generate_release_notes.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

pushd capi-release-main > /dev/null
  # get tag of last release from "main" branch
  PREVIOUS_VERSION="$(git describe --tags --abbrev=0)"
popd > /dev/null

pushd capi-release-ci-passed > /dev/null
  # get latest commit id of "ci-passed" branch (= new release candidate)
  CI_PASSED_VERSION="$(git rev-parse HEAD)"
  "$SCRIPT_DIR/release_notes.rb" "$PREVIOUS_VERSION" "$CI_PASSED_VERSION" "src/cloud_controller_ng"
popd > /dev/null
