#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

pushd capi-release > /dev/null
  mapfile -t VERSIONS < <(git tag --sort=-v:refname | grep '^1\.' | head -n2)
  VERSION=${VERSIONS[0]}
  PREVIOUS_VERSION=${VERSIONS[1]}

  "$SCRIPT_DIR/release_notes.rb" $PREVIOUS_VERSION $VERSION
popd > /dev/null
