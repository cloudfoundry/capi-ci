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
environment="$( cat "${workspace_dir}/environment/name" )"

# TASK
gcloud auth activate-service-account --key-file=<( echo "${GCP_JSON_KEY}" )

remote_path="gs://${GCP_BUCKET}/"
if [ -n "${GCP_PATH}" ]; then
  remote_path="${remote_path}${GCP_PATH}/"
fi
if [ "${USE_ENV_NAMED_SUBDIR}" == "true" ]; then
  remote_path="${remote_path}${environment}"
fi
gsutil rm -r "${remote_path}"
