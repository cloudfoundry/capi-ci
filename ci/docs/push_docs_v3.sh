#!/usr/bin/env bash

set -e

function setup_ssh_for_git() {
  mkdir ${HOME}/.ssh
  chmod 0700 ${HOME}/.ssh
  ssh-keyscan -H github.com >> ${HOME}/.ssh/known_hosts
  chmod 0644 ${HOME}/.ssh/known_hosts

  echo "${GITHUB_PUSH_KEY}" > /tmp/push_rc_docs_key
  chmod 600 /tmp/push_rc_docs_key
  eval $(ssh-agent -s)
  ssh-add /tmp/push_rc_docs_key
  rm /tmp/push_rc_docs_key
}

function setup_git_user() {
  git config user.name 'ari-wg-gitbot'
  git config user.email 'app-runtime-interfaces@cloudfoundry.org'
}

function build_v3_docs() {
  ./scripts/publish_docs_for_version.sh ${VERSION}
}

function get_v3_version_from_cc() {
  VERSION=$(cat config/version)
}

function main() {
  pushd capi-release/src/cloud_controller_ng
    setup_ssh_for_git
    setup_git_user
    get_v3_version_from_cc
    build_v3_docs
  popd
}

main
