#!/usr/bin/env bash

set -e

BOSH_ENV=""
CA_CERTIFICATES=()

function setup_environment() {
  echo "Setting up bbl env ..."
  pushd "bbl-state/${BBL_STATE_DIR}" > /dev/null
    eval "$(bbl print-env)"
  popd > /dev/null

  BOSH_ENV="$(bosh environment --json | jq -r .Tables[0].Rows[0].name)"
  echo "BOSH environment is $BOSH_ENV"

  IFS=, read -r -a CA_CERTIFICATES <<< "$CA_CERTS"
}

function rotate_step_1() {
  echo "Rotating CA certificates - step 1 ..."

  for ca_cert in "${CA_CERTIFICATES[@]}"
  do
    echo "Generating new transitional version for $ca_cert ..."
    ca_cert_guid="$(credhub curl -p "/api/v1/certificates?name=/$BOSH_ENV/cf/$ca_cert" | jq -r .certificates[0].id)"
    # if certificate is already marked as transitional, the command will throw an error message and exit with 0
    set -x
    credhub curl -p "/api/v1/certificates/$ca_cert_guid/regenerate" -d '{"set_as_transitional": true}' -X POST
    set +x
  done
}

function rotate_step_2() {
  echo "Rotating CA certificates - step 2 ..."

  for ca_cert in "${CA_CERTIFICATES[@]}"
  do
    echo "Moving transitional flag for $ca_cert ..."
    ca_cert_guid="$(credhub curl -p "/api/v1/certificates?name=/$BOSH_ENV/cf/$ca_cert" | jq -r .certificates[0].id)"
    # CredHub API: versions are sorted in descending order of their creation date -> [1] is previous (active) version and has "transitional": false
    ca_cert_older_version="$(credhub curl -p "/api/v1/certificates?name=/$BOSH_ENV/cf/$ca_cert" | jq -r '.certificates[0].versions[1].id')"
    set -x
    credhub curl -p "/api/v1/certificates/$ca_cert_guid/update_transitional_version" -d "{\"version\": \"$ca_cert_older_version\"}" -X PUT
    set +x

    echo "Regenerating signed certificates ..."
    credhub curl -p "/api/v1/bulk-regenerate" -d "{\"signed_by\": \"/$BOSH_ENV/cf/$ca_cert\"}" -X POST
  done
}

function rotate_step_3() {
  echo "Rotating CA certificates - step 3 ..."

  for ca_cert in "${CA_CERTIFICATES[@]}"
  do
    echo "Removing transitional flag for $ca_cert ..."
    ca_cert_guid="$(credhub curl -p "/api/v1/certificates?name=/$BOSH_ENV/cf/$ca_cert" | jq -r .certificates[0].id)"
    set -x
    # CredHub API: "version": null ensures that no versions are transitional
    credhub curl -p "/api/v1/certificates/$ca_cert_guid/update_transitional_version" -d '{"version": null}' -X PUT
    set +x
  done
}

function main() {
  setup_environment
  rotate_"$STEP"
  echo "Done"
}

main
