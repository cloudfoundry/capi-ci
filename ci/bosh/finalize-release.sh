#!/usr/bin/env bash

set -e

FINAL_RELEASE_VERSION=$(cat next-version/version)

function setup_git_user() {
  pushd capi-release > /dev/null
    git config user.name 'ari-wg-gitbot'
    git config user.email 'app-runtime-interfaces@cloudfoundry.org'
  popd > /dev/null
}

function set_private_yml() {
  if [[ -z "${PRIVATE_YAML}" ]]; then
    echo "Error: PRIVATE_YAML is not set."
    exit 1
  fi

  echo "${PRIVATE_YAML}" > "${PWD}/capi-release/config/private.yml"
}

function create_release() {
  pushd capi-release > /dev/null
    bosh -n create-release \
      --final \
      --sha2 \
      --tarball "../finalized-release-tarball/capi-${FINAL_RELEASE_VERSION}.tgz" \
      --version "${FINAL_RELEASE_VERSION}"

    git add -A
    git commit -m "Create final release ${FINAL_RELEASE_VERSION}"
  popd > /dev/null
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
