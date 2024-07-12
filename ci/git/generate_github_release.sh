#!/usr/bin/env bash

set -eu

FINAL_RELEASE_DIR=capi-final-releases/
PREVIOUS_RELEASE_TAG=$(cat github-published-release/tag)
pushd capi-release > /dev/null
  SHA_CAPI=$(git rev-parse HEAD )
  echo $SHA_CAPI > ../$FINAL_RELEASE_DIR/commitish
  PREVIOUS_SHA_CC=$(git rev-parse $PREVIOUS_RELEASE_TAG:./src/cloud_controller_ng)
  pushd src/cloud_controller_ng > /dev/null
    SHA_CC=$(git rev-parse HEAD)
    MIGRATIONS=($(git diff --diff-filter=A --name-only $PREVIOUS_SHA_CC db/migrations))
    pushd config > /dev/null
      VERSION_V2=$(cat version_v2)
      VERSION_V3=$(cat version)
      VERSION_BROKER_API=$(cat osbapi_version)
    popd > /dev/null
  popd > /dev/null
popd > /dev/null

ALL_CAPI_REL_TGZS=( "$FINAL_RELEASE_DIR"/capi-*.tgz )

if [ ${#ALL_CAPI_REL_TGZS[@]} -gt 1 ]; then
  echo "Error: More than one file matches the pattern 'capi-*.tgz'"
  exit 1
elif [[ ! -e ${ALL_CAPI_REL_TGZS[0]} ]]; then
  echo "Error: No file matches the pattern 'capi-*.tgz'"
  exit 1
fi

CAPI_REL_TGZ=$(basename "${ALL_CAPI_REL_TGZS[0]}")
VERSION_CAPI=$(echo $CAPI_REL_TGZ | sed -e 's/^capi-//' -e 's/\.tgz$//')

if [[ $VERSION_CAPI =~ ^[0-9]+\.[0-9]+\.[0-9]+- ]]; then  # Check if the version string is longer than expected
  echo "Error: Invalid version string $VERSION_CAPI in file $CAPI_REL_TGZ"
  exit 1
fi

echo "CAPI ${VERSION_CAPI}" > $FINAL_RELEASE_DIR/name
echo "${VERSION_CAPI}" > $FINAL_RELEASE_DIR/version

MIGRATIONS_FORMATTED=()
if [ ${#MIGRATIONS[@]} -eq '0' ]; then
  MIGRATIONS_FORMATTED+=("None")
else
  for i in "${MIGRATIONS[@]}"
  do
    MIGRATIONS_FORMATTED+=("- [$(basename $i)](https://github.com/cloudfoundry/cloud_controller_ng/blob/$SHA_CC/$i)")
  done
fi

# body == release notes
cat <<EOF > $FINAL_RELEASE_DIR/body
**Highlights**

**CC API Version: $VERSION_V2 and [$VERSION_V3](http://v3-apidocs.cloudfoundry.org/version/$VERSION_V3/)**

**Service Broker API Version: [$VERSION_BROKER_API](https://github.com/openservicebrokerapi/servicebroker/blob/v$VERSION_BROKER_API/spec.md)**

### [CAPI Release](https://github.com/cloudfoundry/capi-release/tree/$SHA_CAPI)

### [Cloud Controller](https://github.com/cloudfoundry/cloud_controller_ng/tree/$SHA_CC)

#### Cloud Controller Database Migrations

$( IFS=$'\n'; echo "${MIGRATIONS_FORMATTED[*]}" )

#### Pull Requests and Issues
EOF

cp -R capi-final-releases/* generated-release/
