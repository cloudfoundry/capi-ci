#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

VERSION=`cat next-version/version`

pushd capi-release > /dev/null
  CAPI_COMMIT_SHA=$(git rev-parse HEAD)

  pushd src/cloud_controller_ng > /dev/null
    CC_COMMIT_SHA=$(git rev-parse HEAD)
  popd > /dev/null

  for i in {1..5}; do
    echo "Syncing blobs, attempt $i"
    bosh sync-blobs --sha2 --parallel=10 && break
  done

  "$SCRIPT_DIR/unused_blobs.rb"

  TARBALL_NAME=capi-${VERSION}-${CAPI_COMMIT_SHA}-${CC_COMMIT_SHA}.tgz
  for i in {1..5}; do
    echo "Creating release, attempt $i"
    bosh create-release --sha2 --tarball=$TARBALL_NAME --version $VERSION --force
    EXIT_STATUS=${PIPESTATUS[0]}
    if [ "$EXIT_STATUS" = "0" ]; then
      break
    fi
  done

  if [ ! "$EXIT_STATUS" = "0" ]; then
    echo "Failed to create CAPI release"
    exit $EXIT_STATUS
  fi

  if [ ! -f $TARBALL_NAME ]; then
    echo "No release tarball found"
    exit 1
  fi

popd > /dev/null

mv capi-release/$TARBALL_NAME created-capi-release/
