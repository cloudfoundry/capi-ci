#!/usr/bin/env bash

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
