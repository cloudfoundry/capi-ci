#!/bin/bash

set -eu

# ENV
: "${GCP_JSON_KEY:?}"

# INPUTS
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
workspace_dir="$( cd "${script_dir}/../../../" && pwd )"
deployment_repo="${workspace_dir}/bosh-deployment"
terraform_dir="${workspace_dir}/terraform"

# OUTPUTS
state_dir="${workspace_dir}/director-state"

additional_args=''
if [ -n "${GCP_INSTANCE_TYPE}" ]; then
  cat > ${script_dir}/custom-vm-size.yml << EOD
---
# Configure sizes for bosh-lite on gcp
- type: replace
  path: /resource_pools/name=vms/cloud_properties/machine_type
  value: ${GCP_INSTANCE_TYPE}
EOD

  additional_args="-o ${script_dir}/custom-vm-size.yml"
elif [ -n "${GCP_INSTANCE_RAM}" ] && [ -n "${GCP_INSTANCE_CPU}" ]; then
  cat > ${script_dir}/custom-vm-size.yml << EOD
---
# Configure sizes for bosh-lite on gcp
- type: replace
  path: /resource_pools/name=vms/cloud_properties/ram
  value: ${GCP_INSTANCE_RAM}
- type: replace
  path: /resource_pools/name=vms/cloud_properties/cpu
  value: ${GCP_INSTANCE_CPU}
EOD

  additional_args="-o ${script_dir}/custom-vm-size.yml"
fi

pushd "${state_dir}" > /dev/null
  bosh interpolate "${deployment_repo}/bosh.yml" \
    -o "${deployment_repo}/gcp/cpi.yml" \
    -o "${deployment_repo}/bosh-lite.yml" \
    -o "${deployment_repo}/bosh-lite-runc.yml" \
    -o "${deployment_repo}/gcp/bosh-lite-vm-type.yml" \
    -o "${deployment_repo}/jumpbox-user.yml" \
    -o "${deployment_repo}/external-ip-not-recommended.yml" \
    -o "${deployment_repo}/uaa.yml" \
    -o "${deployment_repo}/external-ip-not-recommended-uaa.yml" \
    -o "${deployment_repo}/credhub.yml" \
    -o "${script_dir}/use-external-ip-credhub.yml" ${additional_args} \
    -o "${script_dir}/use-ssd-disks.yml" \
    -v director_name="bosh-lite" \
    -v gcp_credentials_json="'${GCP_JSON_KEY}'" \
    -l "${terraform_dir}/metadata" \
    > ./director.yml

    echo -e "\nDeploying new Bosh-Lite..."
    bosh create-env \
       --state ./state.json \
       --vars-store ./creds.yml \
      ./director.yml

    export BOSH_ENVIRONMENT=$(bosh int director.yml --path=/instance_groups/name=bosh/networks/name=public/static_ips/0)
    export BOSH_CA_CERT="$(bosh interpolate --path /default_ca/ca creds.yml)"
    export BOSH_CLIENT="admin"
    export BOSH_CLIENT_SECRET=$(bosh int creds.yml --path=/admin_password)

    echo -e "\nAdding bosh-dns via runtime config..."
    bosh update-runtime-config \
      -n \
      "${deployment_repo}/runtime-configs/dns.yml" \
      --name=dns
popd > /dev/null
