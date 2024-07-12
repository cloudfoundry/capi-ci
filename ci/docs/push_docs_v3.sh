#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function get_v3_version_from_cc() {
  pushd capi-release/src/cloud_controller_ng > /dev/null
    VERSION=$(cat config/version)
  popd > /dev/null
}

function build_docs() {
  "$SCRIPT_DIR/build_docs_v3.sh" "${VERSION}" "${DOCS_DIR}" "${GH_PAGES_DIR}"
}

function commit_docs() {
  pushd cc-api-gh-pages > /dev/null
    git config user.name 'ari-wg-gitbot'
    git config user.email 'app-runtime-interfaces@cloudfoundry.org'

    git add index.html --ignore-errors
    git add versions.json
    git add "version/${VERSION}"

    if [[ "$(git diff --name-only --staged)" == '' ]]; then
      echo "No changes to the docs. Nothing to publish"
    else
      git commit -m "Bump v3 API docs version ${VERSION}"
    fi
  popd > /dev/null
}

function move_to_output_location() {
  cp -r cc-api-gh-pages/. updated-gh-pages
}

function main() {
  if [ -z "$VERSION" ]; then
    get_v3_version_from_cc
  fi

  DOCS_DIR="$( cd capi-release/src/cloud_controller_ng/docs/v3 && pwd )"
  GH_PAGES_DIR="$( cd cc-api-gh-pages && pwd )"

  build_docs
  commit_docs
  move_to_output_location
}

main
