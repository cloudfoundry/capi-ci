#!/bin/bash

set -eu

read_with_escaped_newlines() {
  perl -pe 's|\n|\\n|' "$1"
}

: ${ENV_NAME:?}
: ${DEPLOYMENT_NAME:?}

output_name_file=environment/name
output_metadata_file=environment/metadata

echo "Creating name file..."
echo "${ENV_NAME}" > "${output_name_file}"

echo "Creating bbl vars file..."

if [ -n "${BBL_STATE_DIR:-}" ]; then
  pushd "capi-ci-private/${BBL_STATE_DIR}" > /dev/null
else
  pushd "capi-ci-private/${ENV_NAME}" > /dev/null
fi

eval "$(bbl print-env)"
jumpbox_address="$(bbl print-env | grep BOSH_ALL_PROXY | cut -d'@' -f2 | cut -d'?' -f1)"

cat <<- EOF > "${output_metadata_file}"
  {
    "deployment": "${DEPLOYMENT_NAME}",
    "target": "$(bbl director-address)",
    "client": "$(bbl director-username)",
    "client_secret": "$(bbl director-password)",
    "ca_cert": "$(read_with_escaped_newlines <(bbl director-ca-cert))",
    "gw_user": "jumpbox",
    "gw_host": "$(bbl director-address | cut -d'/' -f3 | cut -d':' -f1)",
    "gw_private_key": "$(read_with_escaped_newlines <(bbl ssh-key))",
    "jumpbox_url": "${jumpbox_address}",
    "jumpbox_ssh_key": "$(read_with_escaped_newlines <(bbl ssh-key))",
    "jumpbox_username": "jumpbox"
  }
EOF

popd > /dev/null

echo "Successfully created bbl vars file at '${output_metadata_file}'!"
