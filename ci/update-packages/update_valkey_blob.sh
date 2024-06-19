#!/bin/bash

set -eu -o pipefail

if [[ -z "${PRIVATE_YAML}" ]]; then
  echo "Error: PRIVATE_YAML is not set."
  exit 1
fi

directories=("$PWD/capi-release" "$PWD/capi-release/config" "$PWD/valkey-release")
for dir in "${directories[@]}"; do
  if [[ ! -d $dir ]]; then
    echo "Error: Directory $dir does not exist."
    exit 1
  fi
done

echo "${PRIVATE_YAML}" > "$PWD"/capi-release/config/private.yml

capi_blobs_path="$PWD/capi-release/config/blobs.yml"

#current_valkey_blob_name=$(grep -m 1  "valkey" "$capi_blobs_path" | awk -F':' '{print $1}') || { echo "Error: grep command failed."; exit 1; }
#current_valkey_version=$(echo "${current_valkey_blob_name}" | awk -F'/' '{print $2}' | awk -F'.tar.gz' '{print $1}') || { echo "Error: awk command failed."; exit 1; }
#echo "Current Valkey version is '${current_valkey_version}'"

#if [ -z "$current_valkey_blob_name" ] || [ -z "$current_valkey_version" ]; then
#  echo "Either no Valkey entry found or no version found for Valkey in blobs.yml."
#  exit 1
#fi

valkey_path="$PWD/valkey-release"
new_valkey_version=$(cat "$valkey_path/version") || { echo "Error: cat command for version failed."; exit 1; }
new_valkey_url=$(cat "$valkey_path/url") || { echo "Error: cat command for url failed."; exit 1; }
echo "New Valkey version is '${new_valkey_version}'"

cp -r "$PWD"/capi-release/. "$PWD"/updated-capi-release

#if [[ "$current_valkey_version" == "$new_valkey_version" ]]; then
#  echo "The current Valkey version is the same as the new version. Exiting..."
#  exit 0
#fi

pushd capi-release
    #bosh remove-blob -n "${current_valkey_blob_name}"
    bosh add-blob -n "$valkey_path/source.tar.gz" valkey/"${new_valkey_version}".tar.gz

    #sed -i "0,/$current_valkey_version/s//$new_valkey_version/" packages/valkey/packaging || { echo "Error: sed command for 'packaging' failed."; exit 1; }
    #sed -i "s/$current_valkey_version/$new_valkey_version/g" packages/valkey/README.md || { echo "Error: sed command for 'README' failed."; exit 1; }
    #sed -i "0,/$current_valkey_version/s//$new_valkey_version/" packages/valkey/spec || { echo "Error: sed command for 'spec' failed."; exit 1; }

    bosh upload-blobs -n

    git --no-pager diff packages .final_builds config

    git config user.name "ari-wg-gitbot"
    git config user.email "app-runtime-interfaces@cloudfoundry.org"

    git add -A packages .final_builds config
    git commit -n --allow-empty -m "Bump Valkey to $new_valkey_version" -m "Changes: $new_valkey_url"  || { echo "Error: git commit failed."; exit 1; }
    cp -r "$PWD"/. ../updated-capi-release
popd
