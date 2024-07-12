#!/bin/bash

set -e

if [[ -z "${PRIVATE_YAML}" ]]; then
  echo "Error: PRIVATE_YAML is not set."
  exit 1
fi

echo "${PRIVATE_YAML}" > "${PWD}/capi-release/config/private.yml"

pushd golang-release > /dev/null
  new_go_version=$(bosh blobs | grep linux | grep go${GO_VERSION} | cut -d . -f 1-3 | sort | tail -1)
popd > /dev/null

pushd capi-release > /dev/null
  bosh vendor-package golang-${GO_VERSION}-linux ../golang-release

  git --no-pager diff packages .final_builds

  git config user.name "ari-wg-gitbot"
  git config user.email "app-runtime-interfaces@cloudfoundry.org"

  git add -A packages .final_builds

  if [[ "$(git diff --name-only --staged)" == '' ]]; then
    echo "No changes"
  else
    git commit -m "Bump Golang to $new_go_version"
  fi
popd > /dev/null

cp -r capi-release/. updated-capi-release
