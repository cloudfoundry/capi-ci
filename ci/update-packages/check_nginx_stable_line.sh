#!/bin/bash

set -eu -o pipefail

pipeline_file="capi-ci/ci/pipeline.yml"
endoflife_url="https://endoflife.date/api/nginx.json"

if [[ ! -f "${pipeline_file}" ]]; then
  echo "Error: ${pipeline_file} not found."
  exit 1
fi

pinned_branch=$(yq '.resources[] | select(.name == "nginx-release") | .source.branch' "${pipeline_file}") || { echo "Error: yq failed to read ${pipeline_file}."; exit 1; }

if [[ -z "${pinned_branch}" || "${pinned_branch}" == "null" ]]; then
  echo "Error: nginx-release resource not found in ${pipeline_file}, or it has no source.branch."
  exit 1
fi

if [[ "${pinned_branch}" != stable-* ]]; then
  echo "Error: nginx-release branch is '${pinned_branch}', expected 'stable-X.Y'."
  exit 1
fi

pinned_cycle="${pinned_branch#stable-}"
echo "Pinned nginx stable line: stable-${pinned_cycle}"

today=$(date -u +%F)

endoflife_json=$(curl -fsSL --retry 3 --retry-delay 5 --retry-all-errors "${endoflife_url}") || { echo "Error: failed to fetch ${endoflife_url} after retries."; exit 1; }

pinned_entry=$(echo "${endoflife_json}" | jq --arg cycle "${pinned_cycle}" '.[] | select(.cycle == $cycle)') || { echo "Error: jq failed to parse response from ${endoflife_url}."; exit 1; }

if [[ -z "${pinned_entry}" ]]; then
  echo "Error: pinned cycle '${pinned_cycle}' not found in ${endoflife_url} response."
  exit 1
fi

pinned_eol=$(echo "${pinned_entry}" | jq -r '.eol')

if [[ "${pinned_eol}" == "false" ]] || [[ "${pinned_eol}" > "${today}" ]]; then
  echo "Pinned nginx stable line is still supported (eol: ${pinned_eol})."
  exit 0
fi

supported_cycles=$(echo "${endoflife_json}" | jq -r --arg today "${today}" '.[] | select(.eol == false or .eol > $today) | .cycle') || { echo "Error: jq failed to filter supported cycles."; exit 1; }

if [[ -z "${supported_cycles}" ]]; then
  echo "Error: no currently-supported nginx cycles found in ${endoflife_url} response."
  exit 1
fi

echo
echo "ERROR: pinned nginx stable line is end-of-life."
echo "  Pinned:    stable-${pinned_cycle}"
echo "  EOL date:  ${pinned_eol}"
echo "  Today:     ${today}"
echo
echo "Currently-supported nginx cycles (per ${endoflife_url}):"
echo "${supported_cycles}" | sed 's/^/  - /'
echo
echo "Pick a stable cycle (even minor version, e.g. 1.30) and update the nginx-release resource in capi-ci/ci/pipeline.yml:"
echo "    branch: stable-<cycle>"
echo "    tag_regex: release-<cycle>\\..*"
exit 1
