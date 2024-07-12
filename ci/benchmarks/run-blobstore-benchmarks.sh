#!/bin/bash

set -eu

: "${BOSH_API_INSTANCE:="api/0"}"
: "${BOSH_DEPLOYMENT_NAME:="cf"}"

bbl_vars_file=environment/metadata

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
tmp_dir="$( mktemp -d /tmp/capi-benchmarks.XXXXXXXXXX )"

tunnel_port="8080"

setup_bbl_environment() {
  pushd "capi-ci-private/${BBL_STATE_DIR}" > /dev/null
    eval "$(bbl print-env)"
  popd > /dev/null
}

write_ssh_key() {
  echo "${green}Writing BOSH GW SSH key...${reset}"

  key_path="${tmp_dir}/bosh.pem"
  echo "${BOSH_GW_PRIVATE_KEY_CONTENTS}" > "${key_path}"
  chmod 600 "${key_path}"
  export BOSH_GW_PRIVATE_KEY="${key_path}"
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

cache_ip_for_hostname() {
  dns_hostname="$1"
  echo "${green}Saving IP address for '${dns_hostname}' to /etc/hosts...${reset}"

  # `head -n1 | xargs echo` forces the CLI into non-tty mode and trims newlines
  db_ip="$(bosh ssh -d "${BOSH_DEPLOYMENT_NAME}" "${BOSH_API_INSTANCE}" \
    -c "dig +short ${dns_hostname}" -r --column=Stdout | head -n1 | xargs echo)"

  # BOSH CLI return '-' if stdout is empty
  if [ "${db_ip}" != "-" ]; then
    if [ "$(uname -s)" == "Darwin" ]; then
      echo "${db_ip} ${dns_hostname}" | sudo tee -a /etc/hosts
    else
      echo "${db_ip} ${dns_hostname}" >> /etc/hosts
    fi
  fi
}

perform_blobstore_benchmarks() {
  echo "${green}Performing blobstore benchmarks...${reset}"
  bosh ssh -d "${BOSH_DEPLOYMENT_NAME}" "${BOSH_API_INSTANCE}"  sudo /var/vcap/jobs/cloud_controller_ng/bin/perform_blobstore_benchmarks
}

cleanup() {
  echo "${green}Cleaning up...${reset}"
  kill_background_ssh_tunnel
  rm -rf "${tmp_dir}"
  echo "${green}Finished cleanup.${reset}"
}

main() {
  setup_bbl_environment
  write_ssh_key
  start_background_ssh_tunnel

  trap 'cleanup' EXIT

  # manually create Hostname -> IP records as DNS lookups don't go thru the SSH tunnel
  cache_ip_for_hostname "sql-db.service.cf.internal"

  perform_blobstore_benchmarks
}

main

echo -e "${green}Successfully performed blobstore benchmarks !${reset}\n"
