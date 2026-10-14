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

account_name="$(yaml_get blobstore_storage_account_name)"
account_key="$(yaml_get blobstore_storage_access_key)"
buildpack_container="$(yaml_get buildpack_directory_key)"
droplet_container="$(yaml_get droplet_directory_key)"
package_container="$(yaml_get app_package_directory_key)"
resource_container="$(yaml_get resource_directory_key)"

for required in \
  account_name \
  account_key \
  buildpack_container \
  droplet_container \
  package_container \
  resource_container; do
  if [[ -z "${!required}" ]]; then
    echo "missing ${required} in ${vars_file}" >&2
    exit 1
  fi
done

for container in "${buildpack_container}" "${droplet_container}" "${package_container}" "${resource_container}"; do
  echo "Deleting blobs from container ${container} in account ${account_name}"
  az storage blob delete-batch \
    --account-name "${account_name}" \
    --account-key "${account_key}" \
    --source "${container}" \
    --only-show-errors

done

