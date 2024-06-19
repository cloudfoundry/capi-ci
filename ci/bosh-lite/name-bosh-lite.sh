#!/bin/bash

set -eu

# INPUTS
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
workspace_dir="$( cd "${script_dir}/../../.." && pwd )"

# OUTPUTS
env_name="${workspace_dir}/env-name/env-name"

grep '^.\{1,10\}$' /usr/share/dict/words | shuf -n1 | tr '[:upper:]' '[:lower:]' | tee "$env_name"
