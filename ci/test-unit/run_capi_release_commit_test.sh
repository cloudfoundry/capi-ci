#!/usr/bin/env bash
set -e

cd capi-release-main
commit="$(git log -n 1 --pretty=format:'%s')"
[[ $commit =~ 'Create final release '[0-9]+[.0-9]+$ ]]
