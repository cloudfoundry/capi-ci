#!/usr/bin/env bash

set -e

function setup_bosh_env_vars() {
  echo "Setting up bbl env ..."
  pushd "bbl-state/${BBL_STATE_DIR}" > /dev/null
    eval "$(bbl print-env)"
  popd > /dev/null
}

function bosh_redeploy() {
  echo "Redeploying CF ..."
  bosh -d cf manifest > manifest.yml
  bosh -d cf --non-interactive deploy manifest.yml
}

function main() {
  setup_bosh_env_vars
  bosh_redeploy
  echo "Done"
}

main
