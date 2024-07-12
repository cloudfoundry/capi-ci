#!/bin/bash

set -eu

# INPUTS
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
workspace_dir="$( cd "${script_dir}/../../.." && pwd )"
state_dir="${workspace_dir}/director-state"

pushd "${state_dir}" > /dev/null
  echo -e "\nDestroying the Bosh-Lite..."
  set +e
  bosh delete-env \
    --state ./state.json \
    --vars-store ./creds.yml \
    ./director.yml
  exit_code="$?"
  set -e

  if [ "${exit_code}" != "0" ]; then
    echo "Failed to delete bosh-lite. Continuing as it may have been deleted out of band..."
  fi

  echo "Done"
popd > /dev/null
