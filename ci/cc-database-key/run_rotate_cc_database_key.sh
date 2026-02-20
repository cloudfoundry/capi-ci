#!/bin/bash
set -eu

: "${BOSH_DEPLOYMENT_NAME:="cf"}"
: "${BBL_STATE_DIR:?}"

echo "Setting up BBL environment from ${BBL_STATE_DIR}..."
pushd "capi-ci-private/${BBL_STATE_DIR}" > /dev/null
  eval "$(bbl print-env)"
popd > /dev/null

echo ""
echo "===== Running errand: rotate-cc-database-key (deployment: ${BOSH_DEPLOYMENT_NAME}) ====="
bosh -d "${BOSH_DEPLOYMENT_NAME}" run-errand rotate-cc-database-key
echo "===== Errand completed successfully ====="
