#!/usr/bin/env bash

set -eu

BBL_VERSION=$(cat bbl-github-release/version)

pushd capi-dockerfiles > /dev/null
  for dockerfile in $(grep -Rl "ENV bbl_version" .); do
    sed -i "s/ENV bbl_version.*$/ENV bbl_version $BBL_VERSION/" $dockerfile
  done

  if [[ -n $(git status --porcelain) ]]; then
    git config user.name "ari-wg-gitbot"
    git config user.email "app-runtime-interfaces@cloudfoundry.org"
    git add .
    git commit --allow-empty \
      -m "Update bbl version in Dockerfiles"
  fi
popd > /dev/null

git clone capi-dockerfiles capi-dockerfiles-updated
