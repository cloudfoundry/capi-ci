#!/bin/bash
set -eu

function setup_bosh_env_vars() {
  echo "Setting env vars..."
  pushd "bbl-state/${BBL_STATE_DIR}"
    eval "$(bbl print-env)"
  popd
}

function bosh_clean_up() {
  echo "Running bosh clean-up on ${BOSH_ENVIRONMENT}..."
  bosh -n clean-up --all
}

function main() {
  setup_bosh_env_vars
  bosh_clean_up
  echo "Done"
}

main
