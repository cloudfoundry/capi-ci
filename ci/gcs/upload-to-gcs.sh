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
source_dir="${workspace_dir}/source-directory"
environment="$( cat ${workspace_dir}/environment/name )"

# TASK
gcloud auth activate-service-account --key-file=<( echo "${GCP_JSON_KEY}" )

pushd "${source_dir}" > /dev/null
  remote_path="gs://${GCP_BUCKET}/"
  if [ -n "${GCP_PATH}" ]; then
    remote_path="${remote_path}${GCP_PATH}/"
  fi
  if [ "${USE_ENV_NAMED_SUBDIR}" == "true" ]; then
    remote_path="${remote_path}${environment}"
  fi

  gsutil rsync . "${remote_path}"
popd > /dev/null
