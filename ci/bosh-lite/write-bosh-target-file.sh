#!/bin/bash

set -eu

indent() {
  sed -e 's/^/  /'
}

indent_contents_of() {
  indent < "$1"
}

# INPUTS
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
workspace_dir="$( cd "${script_dir}/../../.." && pwd )"
env_info="${workspace_dir}/bosh-lite-env-info"

# OUTPUTS
output_dir="${workspace_dir}/bosh-target"

source "${env_info}/metadata"
env_name="$(cat "${env_info}/name")"

## Create target.json
output_file="${output_dir}/target.yml"
cat <<- EOF > "${output_file}"
---
deployment: "cf"
target: "${BOSH_ENVIRONMENT}"
client: "${BOSH_CLIENT}"
client_secret: "${BOSH_CLIENT_SECRET}"
ca_cert: |
$(indent_contents_of <( echo "${BOSH_CA_CERT}" ))
vars_store:
  config:
    file_name: "director-state/${env_name}/cf-creds.yml"
EOF
echo "Successfully created bosh target file at '${output_file}'!"

## Create vars.yml
output_file="${output_dir}/vars.yml"
cat <<- EOF > "${output_file}"
---
system_domain: "${BOSH_LITE_DOMAIN}"
EOF
echo "Successfully created cf-deployment vars file at '${output_file}'!"
