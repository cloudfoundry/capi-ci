#!/usr/bin/env bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 <target>"
  exit 1
fi

target=$1

# List of pipeline files
files=(
  "./ci/pipeline-bosh-lite.yml"
  "./ci/pipeline-certificate-validation.yml"
  "./ci/cve-pipeline.yml"
  "./ci/pipeline.yml"
  "./ci/pipeline-docker.yml"
)

# Corresponding pipeline names
names=(
  "bosh-lites"
  "capi-cert-validation"
  "cve-scan"
  "capi"
  "docker-builds"
)

if [ ${#files[@]} -ne ${#names[@]} ]; then
  echo "Error: The number of files does not match the number of pipeline names."
  exit 1
fi

# Iterate over the arrays and call the 'fly set-pipeline' command
for i in "${!files[@]}"; do
  file="${files[$i]}"
  name="${names[$i]}"
  echo "Setting pipeline '$name' from file '$file'"
  fly -t "$target" set-pipeline -p "$name" -c "$file"
done
