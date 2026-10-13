#!/bin/bash

set -euo pipefail

: "${BBL_STATE_DIR:?}"

vars_file="bbl-state/${BBL_STATE_DIR}/vars/director-vars-file.yml"
if [[ ! -f "${vars_file}" ]]; then
  echo "director vars file not found: ${vars_file}" >&2
  exit 1
fi

yaml_get() {
  local key="$1"
  sed -nE "s/^[[:space:]]*${key}:[[:space:]]*['\"]?([^'\"#]+)['\"]?[[:space:]]*$/\1/p" "${vars_file}" | head -n1
}

blobstore_access_key_id="$(yaml_get blobstore_access_key_id)"
blobstore_secret_access_key="$(yaml_get blobstore_secret_access_key)"
aws_region="$(yaml_get aws_region)"
buildpack_bucket="$(yaml_get buildpack_directory_key)"
droplet_bucket="$(yaml_get droplet_directory_key)"
package_bucket="$(yaml_get app_package_directory_key)"
resource_bucket="$(yaml_get resource_directory_key)"

for required in \
  blobstore_access_key_id \
  blobstore_secret_access_key \
  aws_region \
  buildpack_bucket \
  droplet_bucket \
  package_bucket \
  resource_bucket; do
  if [[ -z "${!required}" ]]; then
    echo "missing ${required} in ${vars_file}" >&2
    exit 1
  fi
done

export AWS_ACCESS_KEY_ID="${blobstore_access_key_id}"
export AWS_SECRET_ACCESS_KEY="${blobstore_secret_access_key}"
export AWS_DEFAULT_REGION="${aws_region}"
export AWS_PAGER=""

for bucket in "${buildpack_bucket}" "${droplet_bucket}" "${package_bucket}" "${resource_bucket}"; do
  echo "Deleting all objects from s3://${bucket}/"
  aws s3 rm "s3://${bucket}/" --recursive
done

