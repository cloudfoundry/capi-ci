#!/bin/bash

set -eu

# ENV
: "${BOSH_API_INSTANCE:="api/0"}"
: "${BOSH_DEPLOYMENT_NAME:="cf"}"

# INPUTS
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
workspace_dir="$( cd "${script_dir}/../../.." && pwd )"
bbl_vars_file="${workspace_dir}/environment/metadata"

BOSH_ENVIRONMENT="$(jq -e -r .target "${bbl_vars_file}")"
BOSH_CLIENT="$(jq -e -r .client "${bbl_vars_file}")"
BOSH_CLIENT_SECRET="$(jq -e -r .client_secret "${bbl_vars_file}")"
BOSH_CA_CERT="$(jq -e -r .ca_cert "${bbl_vars_file}")"
BOSH_GW_USER="$(jq -e -r .gw_user "${bbl_vars_file}")"
BOSH_GW_HOST="$(jq -e -r .gw_host "${bbl_vars_file}")"
BOSH_GW_PRIVATE_KEY_CONTENTS="$(jq -e -r .gw_private_key "${bbl_vars_file}")"

JUMPBOX_URL="$(jq -e -r .jumpbox_url "${bbl_vars_file}")"
JUMPBOX_SSH_KEY="$(jq -e -r .jumpbox_ssh_key "${bbl_vars_file}")"
JUMPBOX_USERNAME="$(jq -e -r .jumpbox_username "${bbl_vars_file}")"

export BOSH_ENVIRONMENT BOSH_CLIENT BOSH_CLIENT_SECRET BOSH_CA_CERT \
  BOSH_GW_USER BOSH_GW_HOST BOSH_GW_PRIVATE_KEY_CONTENTS \
  JUMPBOX_URL JUMPBOX_SSH_KEY JUMPBOX_USERNAME

green="$(tput -T xterm-256color setaf 2)"
reset="$(tput -T xterm-256color sgr0)"
tmp_dir="$( mktemp -d /tmp/capi-migrations.XXXXXXXXXX )"

tunnel_port="8080"

setup_bbl_environment() {
  pushd "capi-ci-private/${BBL_STATE_DIR}"
    eval "$(bbl print-env)"
  popd
}

write_ssh_key() {
  echo "${green}Writing BOSH GW SSH key...${reset}"

  key_path="${tmp_dir}/bosh.pem"
  echo "${BOSH_GW_PRIVATE_KEY_CONTENTS}" > "${key_path}"
  chmod 600 "${key_path}"
  export BOSH_GW_PRIVATE_KEY="${key_path}"
}

download_cloud_controller_config() {
  echo "${green}Download cloud controller config...${reset}"

  config_path="${tmp_dir}/cloud_controller_ng.yml"
  bosh -d "${BOSH_DEPLOYMENT_NAME}" scp \
   "${BOSH_API_INSTANCE}:/var/vcap/jobs/cloud_controller_ng/config/cloud_controller_ng.yml" \
   "${config_path}"

  #  Change config to use newest format for database (instead of database_parts:)
  #  TODO: Remove this after capi-release 1.88
  new_config_path="${tmp_dir}/cloud_controller_ng2.yml"
  awk '!/database: \"post/' "${config_path}" | \
    awk '{sub("database_parts:", "database:", $0); print}' > "${new_config_path}"

  export CLOUD_CONTROLLER_NG_CONFIG="${new_config_path}"
}

start_background_ssh_tunnel() {
  echo "${green}Starting background SSH tunnel as SOCKS Proxy...${reset}"
  ssh_jumpbox_url=$(echo "${JUMPBOX_URL}" | cut -d':' -f1)
  ssh -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' -D ${tunnel_port} -fNC ${JUMPBOX_USERNAME}@${ssh_jumpbox_url} -i ${JUMPBOX_PRIVATE_KEY}
}

kill_background_ssh_tunnel() {
  echo "${green}Killing SSH tunnel...${reset}"

  ssh_pid="$(lsof -i ":${tunnel_port}" | tail -n1 | awk '{ printf $2 }')"
  kill "${ssh_pid}"
}

run_migrations() {
  echo "${green}Applying latest migrations to deployment...${reset}"
  bosh ssh -d "${BOSH_DEPLOYMENT_NAME}" "${BOSH_API_INSTANCE}" "cd /var/vcap/packages/cloud_controller_ng/cloud_controller_ng; source /var/vcap/jobs/cloud_controller_ng/bin/ruby_version.sh; sudo bundle exec rake db:migrate"
  bosh ssh -d "${BOSH_DEPLOYMENT_NAME}" "${BOSH_API_INSTANCE}" "cd /var/vcap/packages/cloud_controller_ng/cloud_controller_ng; source /var/vcap/jobs/cloud_controller_ng/bin/ruby_version.sh; sudo bundle exec rake db:ensure_migrations_are_current"
}

cleanup() {
  echo "${green}Cleaning up...${reset}"
  kill_background_ssh_tunnel
  echo "${green}Finished cleanup.${reset}"
}

main() {
  setup_bbl_environment
  write_ssh_key
  download_cloud_controller_config
  start_background_ssh_tunnel

  trap 'cleanup' EXIT

  run_migrations
}

main

echo -e "${green}Successfully applied migrations!${reset}\n"
