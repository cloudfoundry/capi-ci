#!/usr/bin/env bash

set -e

function get_updated_version() {
  VERSION=$(cat cc-api-v2-version/version)
}

function setup_git_user() {
  git config user.name 'ari-wg-gitbot'
  git config user.email 'app-runtime-interfaces@cloudfoundry.org'
}

function bump_v2_docs() {
  sed -i -e 's/^\(.*api_version.*"\).*\(",\)$/\1'"$VERSION"'\2/' docs/v2/info/get_info.html
}

function commit_docs() {
  git add docs/v2/info/get_info.html
  git commit -m "Bump v2 API docs version ${VERSION}"
}

function move_to_output_location() {
  cp -r cloud_controller_ng/. updated-cloud-controller-ng
}

function main() {
  get_updated_version

  pushd cloud_controller_ng > /dev/null
    setup_git_user
    bump_v2_docs
    commit_docs
  popd > /dev/null

  move_to_output_location
}

main
