#!/bin/bash

set -eu

# ENV
: ${GCP_JSON_KEY:?}
: ${GCP_BUCKET:?}

: ${GCP_PATH:=""}
: ${USE_ENV_NAMED_SUBDIR:="false"}

# INPUTS

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
workspace_dir="$( cd "${script_dir}/../../../" && pwd )"
environment="$( cat ${workspace_dir}/environment/name )"

# OUTPUTS

destination_dir="${workspace_dir}/destination-directory"

# TASK
echo "${GCP_JSON_KEY}" > "${workspace_dir}/service_account_key.json"
gcloud auth activate-service-account --key-file="${workspace_dir}/service_account_key.json"

pushd "${destination_dir}" > /dev/null
  remote_path="gs://${GCP_BUCKET}/"
  if [ -n "${GCP_PATH}" ]; then
    remote_path="${remote_path}${GCP_PATH}/"
  fi
  if [ "${USE_ENV_NAMED_SUBDIR}" == "true" ]; then
    remote_path="${remote_path}${environment}"
  fi

  gsutil rsync "${remote_path}" .
popd > /dev/null
