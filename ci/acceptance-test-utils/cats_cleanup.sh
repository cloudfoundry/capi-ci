#!/bin/bash

set -eu

# ENV
: "${CF_API_TARGET:?}"
: "${CF_DEPLOYMENT_NAME:=cf}"

CF_ADMIN_USERNAME=admin

pushd "capi-ci-private/${BBL_STATE_DIR}"
  eval "$(bbl print-env)"
  export DIRECTOR_NAME="$(jq -e -r .bosh.directorName bbl-state.json)"
  unset BOSH_ALL_PROXY
popd

# INPUTS
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
workspace_dir="$( cd "${script_dir}/../../../" && pwd )"

CF_ADMIN_PASSWORD="$(credhub get --name=/${DIRECTOR_NAME}/${CF_DEPLOYMENT_NAME}/cf_admin_password -j | jq .value -r)"

echo "Logging in and setting up..."
cf api $CF_API_TARGET --skip-ssl-validation
cf auth admin "$CF_ADMIN_PASSWORD"

echo "Deleting orphaned test resources"
cf buildpacks | grep -E 'CATS|BARA|SMOKE|SITS' | awk 'NF { print $2 }' | xargs --no-run-if-empty -n 1 cf delete-buildpack -f
cf orgs | grep -E 'WATS|CATS|BARA|SMOKE|SITS' | grep -v persistent | awk 'NF { print $0 }' | xargs --no-run-if-empty -n 1 cf delete-org -f
cf quotas | grep -E 'WATS|CATS|BARA|SMOKE|SITS' | grep -v persistent | awk 'NF { print $1 }' | xargs --no-run-if-empty -n 1 cf delete-quota -f
cf service-brokers | grep -E 'WATS|CATS|BARA|SMOKE|SITS' | grep -v persistent | awk 'NF { print $1 }' | xargs --no-run-if-empty -n 1 cf delete-service-broker -f
cf running-environment-variable-group | grep -E 'WATS|CATS|BARA|SMOKE|SITS' | grep -v persistent | awk 'NF { print "\047{\"var\": {\""$1"\":null}}\047" }' | xargs --no-run-if-empty -n 1 cf curl -X PATCH /v3/environment_variable_groups/running -d
cf staging-environment-variable-group | grep -E 'WATS|CATS|BARA|SMOKE|SITS' | grep -v persistent | awk 'NF { print "\047{\"var\": {\""$1"\":null}}\047" }' | xargs --no-run-if-empty -n 1 cf curl -X PATCH /v3/environment_variable_groups/staging -d

echo "Success!"
