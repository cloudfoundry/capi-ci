#!/usr/bin/env bash

set -e

function setup_git_user() {
  git config user.name 'ari-wg-gitbot'
  git config user.email 'app-runtime-interfaces@cloudfoundry.org'
}

function bump_v2_docs() {
  sed -i -e 's/^\(.*api_version.*"\).*\(",\)$/\1'"$VERSION"'\2/' docs/v2/info/get_info.html
}

function get_updated_version() {
  VERSION=$(cat version)
}

function commit_docs() {
  git add docs/v2/info/get_info.html
  git commit -m "Bump v2 API docs version ${VERSION}"
}

function move_cc_to_output_location() {
  cp -a cloud_controller_ng cloud_controller_ng_bumped_docs
}

function main() {
  pushd cc-api-v2-version
    get_updated_version
  popd
  pushd cloud_controller_ng
    setup_git_user
    bump_v2_docs
    commit_docs
  popd
  move_cc_to_output_location
}

main
