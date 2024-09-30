#!/usr/bin/env bash

set -eu

BOSH_CLI_VERSION=$(cat bosh-cli-github-release/version)

pushd capi-dockerfiles > /dev/null
  for dockerfile in $(grep -Rl "ENV bosh_cli_version" .); do
    sed -i "s/ENV bosh_cli_version.*$/ENV bosh_cli_version=$BOSH_CLI_VERSION/" $dockerfile
  done

  if [[ -n $(git status --porcelain) ]]; then
    git config user.name "ari-wg-gitbot"
    git config user.email "app-runtime-interfaces@cloudfoundry.org"
    git add .
    git commit --allow-empty \
      -m "Update bosh-cli version in Dockerfiles"
  fi
popd > /dev/null

git clone capi-dockerfiles capi-dockerfiles-updated
