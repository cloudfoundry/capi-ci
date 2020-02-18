#!/bin/bash

set -eux -o pipefail

gcloud auth activate-service-account \
  "${GOOGLE_SERVICE_ACCOUNT_EMAIL}" \
  --key-file="${GOOGLE_KEY_FILE_PATH}" \
  --project="${GOOGLE_PROJECT_NAME}"

source "capi-ci-private/${CAPI_ENVIRONMENT_NAME}/.envrc"
pushd "cf-for-k8s"
  hack/generate-values.sh "${CAPI_ENVIRONMENT_NAME}.capi.land" > cf-install-values.yml
  bin/install-cf.sh ./cf-install-values.yml
popd
