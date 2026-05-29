# #!/bin/bash

# set -eu -o pipefail

# if [[ -z "${PRIVATE_YAML}" ]]; then
#   echo "Error: PRIVATE_YAML is not set."
#   exit 1
# fi

# echo "${PRIVATE_YAML}" > "${PWD}/capi-release/config/private.yml"

pushd capi-release > /dev/null
  current_jemalloc_blob_fullname=$(yq '. | keys | map(select(test("jemalloc"))) | .[0]' config/blobs.yml) || { echo "Error: yq failed to read blobs.yml."; exit 1; }
  current_jemalloc_version=$(yq '. | keys | map(select(test("jemalloc"))) | .[0] | capture("jemalloc-(?P<version>[0-9.]+)\.tar\.bz2") | .version' config/blobs.yml) || { echo "Error: yq failed to parse jemalloc version."; exit 1; }

  if [ -z "$current_jemalloc_blob_fullname" ] || [ -z "$current_jemalloc_version" ]; then
    echo "Error: Either no jemalloc entry found in blobs.yml or could not parse the version."
    exit 1
  fi

  echo "Current jemalloc version is '${current_jemalloc_version}'"
popd > /dev/null

# pushd jemalloc-release > /dev/null
#   new_jemalloc_version=$(cat version) || { echo "Error: cat command for version failed."; exit 1; }
#   new_jemalloc_tarball="${PWD}/jemalloc-${new_jemalloc_version}.tar.bz2"
#   new_jemalloc_url=$(cat url) || { echo "Error: cat command for url failed."; exit 1; }
#   echo "New jemalloc version is '${new_jemalloc_version}'"
# popd > /dev/null

# if [[ "$current_jemalloc_version" == "$new_jemalloc_version" ]]; then
#   echo "jemalloc is already at version '${current_jemalloc_version}', nothing to update."
# else
#   pushd capi-release > /dev/null
#     bosh remove-blob -n "${current_jemalloc_blob_fullname}"
#     bosh add-blob -n "$new_jemalloc_tarball" jemalloc/jemalloc-"${new_jemalloc_version}".tar.bz2

#     sed -i "0,/$current_jemalloc_version/s//$new_jemalloc_version/" packages/jemalloc/packaging || { echo "Error: sed command for 'packaging' failed."; exit 1; }
#     sed -i "s/$current_jemalloc_version/$new_jemalloc_version/g" packages/jemalloc/README.md || { echo "Error: sed command for 'README' failed."; exit 1; }
#     sed -i "0,/$current_jemalloc_version/s//$new_jemalloc_version/" packages/jemalloc/spec || { echo "Error: sed command for 'spec' failed."; exit 1; }

#     bosh upload-blobs -n

#     git --no-pager diff packages .final_builds config

#     git config user.name "ari-wg-gitbot"
#     git config user.email "app-runtime-interfaces@cloudfoundry.org"

#     git add -A packages .final_builds config
#     git commit -m "Bump jemalloc to $new_jemalloc_version" -m "Changes: $new_jemalloc_url"  || { echo "Error: git commit failed."; exit 1; }
#   popd > /dev/null
# fi

# cp -r capi-release/. updated-capi-release
