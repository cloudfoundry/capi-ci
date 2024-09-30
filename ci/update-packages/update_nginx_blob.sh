#!/bin/bash

set -eu -o pipefail

if [[ -z "${PRIVATE_YAML}" ]]; then
  echo "Error: PRIVATE_YAML is not set."
  exit 1
fi

echo "${PRIVATE_YAML}" > "${PWD}/capi-release/config/private.yml"

pushd capi-release > /dev/null
  current_nginx_blob_name=$(grep -E "nginx/nginx-[0-9]{1,}.[0-9]{1,}.[0-9]{1,}" config/blobs.yml | awk -F':' '{print $1}') || { echo "Error: grep command failed."; exit 1; }
  current_nginx_version=$(echo "${current_nginx_blob_name}" | awk -F'-' '{print $2}' | awk -F'.tar.gz' '{print $1}') || { echo "Error: awk command failed."; exit 1; }

  if [ -z "$current_nginx_blob_name" ] || [ -z "$current_nginx_version" ]; then
    echo "Either no nginx entry found or no version found for nginx in blobs.yml."
    exit 1
  fi

  echo "Current nginx version is '${current_nginx_version}'"
popd > /dev/null

pushd nginx-release > /dev/null
  new_nginx_version="$(git describe --exact-match --tags | awk -F'-' '{print $2}')" || { echo "Error: git describe command for current tag failed."; exit 1; }
  echo "New nginx version is '${new_nginx_version}'"
popd > /dev/null

if [[ "$current_nginx_version" == "$new_nginx_version" ]]; then
  echo "The current nginx version is the same as the new version."
else
  echo "Importing nginx developer PGP keys..."
  for pgp_key in capi-ci/ci/update-packages/nginx-pgp-keys/*.key; do
    echo "Importing PGP key ${pgp_key}"
    gpg --import "${pgp_key}"
  done
  echo "Downloading nginx archive..."
  wget -O "nginx-${new_nginx_version}.tar.gz"     "https://nginx.org/download/nginx-${new_nginx_version}.tar.gz"
  echo "Downloading nginx archive signature file..."
  wget -O "nginx-${new_nginx_version}.tar.gz.asc" "https://nginx.org/download/nginx-${new_nginx_version}.tar.gz.asc"
  echo "Verifying signature for nginx archive..."
  gpg --verify "nginx-${new_nginx_version}.tar.gz.asc" "nginx-${new_nginx_version}.tar.gz"

  pushd capi-release > /dev/null
    bosh remove-blob -n "${current_nginx_blob_name}"
    bosh add-blob -n "../nginx-${new_nginx_version}.tar.gz" nginx/nginx-"${new_nginx_version}".tar.gz

    sed -i "s/nginx-$current_nginx_version/nginx-$new_nginx_version/g" packages/nginx/packaging || { echo "Error: sed command for 'packaging' failed."; exit 1; }
    sed -i "s/nginx-$current_nginx_version/nginx-$new_nginx_version/g" packages/nginx/README.md || { echo "Error: sed command for 'README' failed."; exit 1; }
    sed -i "s/nginx-$current_nginx_version/nginx-$new_nginx_version/g" packages/nginx/spec || { echo "Error: sed command for 'spec' failed."; exit 1; }

    bosh upload-blobs -n

    git --no-pager diff packages .final_builds config

    git config user.name "ari-wg-gitbot"
    git config user.email "app-runtime-interfaces@cloudfoundry.org"

    git add -A packages .final_builds config
    git commit -m "Bump nginx to $new_nginx_version" -m "Changes: https://nginx.org/en/CHANGES"  || { echo "Error: git commit failed."; exit 1; }
  popd > /dev/null
fi

cp -r capi-release/. updated-capi-release
