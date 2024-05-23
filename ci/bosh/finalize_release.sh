#!/usr/bin/env bash

set -e

source ~/.bashrc

FINAL_RELEASE_VERSION=$(cat next-version/version)

function setup_git_user() {
  pushd capi-release
    git config user.name 'ari-wg-gitbot'
    git config user.email app-runtime-interfaces@cloudfoundry.org
  popd
}

function set_private_yml() {
  echo "${PRIVATE_YAML}" > ${PWD}/capi-release/config/private.yml
}

function create_release() {
  pushd capi-release
    bosh -n create-release \
      --final \
      --sha2 \
      --tarball "../finalized-release-tarball/capi-${FINAL_RELEASE_VERSION}.tgz" \
      --version "${FINAL_RELEASE_VERSION}"

    git add -A
    git commit -m "Create final release ${FINAL_RELEASE_VERSION}"
  popd
}

function export_release() {
  cp -ar capi-release finalized-release-git-repo/
}

function main() {
  setup_git_user
  set_private_yml
  create_release
  export_release
}

main
