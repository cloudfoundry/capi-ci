#!/usr/bin/env bash

set -eu

FINAL_RELEASE_DIR=capi-final-releases/
PREVIOUS_RELEASE_TAG=$(cat github-published-release/tag)
pushd capi-release > /dev/null
  SHA_CAPI=$(git rev-parse HEAD)
  echo "$SHA_CAPI" > "../$FINAL_RELEASE_DIR/commitish"
  ruby ../release_notes.rb "$PREVIOUS_RELEASE_TAG" HEAD src/cloud_controller_ng > "../$FINAL_RELEASE_DIR/body"
popd > /dev/null

ALL_CAPI_REL_TGZS=( "$FINAL_RELEASE_DIR"/capi-*.tgz )

if [[ ${#ALL_CAPI_REL_TGZS[@]} -gt 1 ]]; then
  echo "Error: More than one file matches the pattern 'capi-*.tgz'"
  exit 1
elif [[ ! -e ${ALL_CAPI_REL_TGZS[0]} ]]; then
  echo "Error: No file matches the pattern 'capi-*.tgz'"
  exit 1
fi

CAPI_REL_TGZ=$(basename "${ALL_CAPI_REL_TGZS[0]}")
VERSION_CAPI=$(echo $CAPI_REL_TGZ | sed -e 's/^capi-//' -e 's/\.tgz$//')

if [[ ! $VERSION_CAPI =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Invalid version string $VERSION_CAPI in file $CAPI_REL_TGZ"
  exit 1
fi

echo "CAPI ${VERSION_CAPI}" > $FINAL_RELEASE_DIR/name
echo "${VERSION_CAPI}" > $FINAL_RELEASE_DIR/version

cp -r capi-final-releases/. generated-release
