#!/usr/bin/env bash

set -eu

function setup_bosh_env_vars() {
  pushd "bbl-state/${BBL_STATE_DIR}" > /dev/null
    eval "$(bbl print-env)"
  popd > /dev/null
}

function upload_release() {
  for filename in release-tarball/*.tgz; do
    bosh upload-release --sha2 "$filename"
  done
}

function main() {
  setup_bosh_env_vars
  upload_release
}

main
