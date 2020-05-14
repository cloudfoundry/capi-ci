#!/bin/bash

set -eu

# INPUTS
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
workspace_dir="$( cd "${script_dir}/../../../" && pwd )"

pushd "${workspace_dir}/capi-kpack-watcher/src/capi-kpack-watcher" >/dev/null
    go test ./...
popd >/dev/null