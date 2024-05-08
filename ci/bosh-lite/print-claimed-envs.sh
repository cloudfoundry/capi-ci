#!/bin/bash

set -eu

# ENV
: "${POOL_NAME:="bosh-lites"}"
: "${MESSAGE_PREFIX:=""}"

# INPUTS
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
workspace_dir="$( cd "${script_dir}/../../../" && pwd )"
pool_dir="${workspace_dir}/env-pool/${POOL_NAME}"

# OUTPUTS
output_file="${workspace_dir}/message/message.txt"

. "${script_dir}/src/print_env_info"

message="Time for another bosh-lite round-up! If you have a bosh-lite claimed that you no longer need, run \`unclaim_bosh_lite ENV_NAME\` to set it free!"
if [ -n "${MESSAGE_PREFIX}" ]; then
message="${MESSAGE_PREFIX} ${message}"
fi
echo "${message}" >> "${output_file}"
echo "" >> "${output_file}"
echo '```' >> "${output_file}"
echo -e "$(print_env_info)" >> "${output_file}"
echo '```' >> "${output_file}"

echo "Message:"
cat "${output_file}"
