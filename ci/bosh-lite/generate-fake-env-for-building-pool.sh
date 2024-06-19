#!/bin/bash

set -eu

# INPUTS
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
workspace_dir="$( cd "${script_dir}/../../.." && pwd )"

# OUTPUTS
output_dir="${workspace_dir}/fake-placeholder-env"

cat /dev/urandom | env LC_CTYPE=C tr -cd 'a-f0-9' | head -c 32 > ${output_dir}/name
touch ${output_dir}/metadata
