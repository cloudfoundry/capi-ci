#!/usr/bin/env bash

set -e

cd capi-release
COMMIT="$(git log -n 1 --pretty=format:'%s')"

if [[ ! $COMMIT =~ 'Create final release '[0-9]+[.0-9]+$ ]]; then
  echo "Error: Invalid commit '$COMMIT'"
  exit 1
fi

echo "Success: Valid commit '$COMMIT'"
