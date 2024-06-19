#!/usr/bin/env bash

set -e

source ~/.bashrc

VERSION=`cat next-version/version`

pushd cloud_controller_ng
  if [ -n "$CC_BRANCH" ]; then
    CC_COMMIT_SHA=$(git rev-parse HEAD)
  fi
popd

pushd capi-release
  CAPI_COMMIT_SHA=$(git rev-parse HEAD)

  pushd src/cloud_controller_ng
    if [ -z "$CC_COMMIT_SHA" ]; then
      CC_COMMIT_SHA=$(git rev-parse HEAD)
    fi
    git fetch
    git checkout $CC_COMMIT_SHA
  popd

  for i in {1..5}; do
    echo "Syncing blobs, attempt $i"
    bosh sync-blobs --sha2 --parallel=10 && break
  done

  #./scripts/unused_blobs

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

popd

mv capi-release/$TARBALL_NAME created-capi-release/
