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

  # archive may not yet be ready immediately for download on nginx.org -> exponential retry
  attempt=1
  max_attempts=4
  retry_delay_sec=300
  while (( attempt <= max_attempts )); do
    echo "Downloading nginx archive (attempt $attempt/$max_attempts)..."
    if ! wget -O "nginx-${new_nginx_version}.tar.gz" "https://nginx.org/download/nginx-${new_nginx_version}.tar.gz"; then
      echo "Command failed, retrying in $retry_delay_sec seconds"
      sleep $retry_delay_sec
      retry_delay_sec=$((retry_delay_sec * 2)) # double the retry delay for the next attempt
      if (( attempt == max_attempts )); then
        echo "Failed to download new nginx archive after $max_attempts retries. Retrigger job when https://nginx.org/download/nginx-${new_nginx_version}.tar.gz is available."
        exit 1
      fi
      ((attempt++))
    else
      break
    fi
  done

  echo "Downloading nginx archive signature file..."
  wget -O "nginx-${new_nginx_version}.tar.gz.asc" "https://nginx.org/download/nginx-${new_nginx_version}.tar.gz.asc"
  echo "Verifying signature for nginx archive..."
  gpg --verify "nginx-${new_nginx_version}.tar.gz.asc" "nginx-${new_nginx_version}.tar.gz"

  pushd capi-release > /dev/null
    bosh remove-blob -n "${current_nginx_blob_name}"
    bosh add-blob -n "../nginx-${new_nginx_version}.tar.gz" nginx/nginx-"${new_nginx_version}".tar.gz

    sed -i "s/nginx-$current_nginx_version/nginx-$new_nginx_version/g" packages/nginx/packaging || { echo "Error: sed command for 'packages/nginx/packaging' failed."; exit 1; }
    sed -i "s/nginx-$current_nginx_version/nginx-$new_nginx_version/g" packages/nginx/README.md || { echo "Error: sed command for 'packages/nginx/README.md' failed."; exit 1; }
    sed -i "s/nginx-$current_nginx_version/nginx-$new_nginx_version/g" packages/nginx/spec || { echo "Error: sed command for 'packages/nginx/spec' failed."; exit 1; }

    sed -i "s/nginx-$current_nginx_version/nginx-$new_nginx_version/g" packages/nginx_webdav/packaging || { echo "Error: sed command for 'packages/nginx_webdav/packaging' failed."; exit 1; }
    sed -i "s/nginx-$current_nginx_version/nginx-$new_nginx_version/g" packages/nginx_webdav/spec || { echo "Error: sed command for 'packages/nginx_webdav/spec' failed."; exit 1; }

    bosh upload-blobs -n

    git --no-pager diff packages .final_builds config

    git config user.name "ari-wg-gitbot"
    git config user.email "app-runtime-interfaces@cloudfoundry.org"

    git add -A packages .final_builds config
    git commit -m "Bump nginx to $new_nginx_version" -m "Changes: https://nginx.org/en/CHANGES"  || { echo "Error: git commit failed."; exit 1; }
  popd > /dev/null
fi

cp -r capi-release/. updated-capi-release
