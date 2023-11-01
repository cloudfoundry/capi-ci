#!/bin/bash
set -xeu

build_dir=${PWD}

cf -v

export CONFIG
CONFIG=$(mktemp)

if [ -n "${GOOGLE_SERVICE_ACCOUNT_EMAIL}" ]; then
  echo "Logging into gcloud..."
  gcloud auth activate-service-account \
    "${GOOGLE_SERVICE_ACCOUNT_EMAIL}" \
    --key-file="${GOOGLE_KEY_FILE_PATH}" \
    --project="${GOOGLE_PROJECT_NAME}"
fi

original_config="${build_dir}/integration-config/${CONFIG_FILE_PATH}"
cp ${original_config} ${CONFIG}

CF_GOPATH=/go/src/github.com/cloudfoundry/

echo "Moving capi-bara-tests onto the gopath..."
mkdir -p $CF_GOPATH
cp -R capi-bara-tests $CF_GOPATH

cd /go/src/github.com/cloudfoundry/capi-bara-tests

export CF_DIAL_TIMEOUT=11

export CF_PLUGIN_HOME=$HOME

./bin/test -keep-going \
  -randomize-all \
  -skip-package=helpers \
  -poll-progress-after=300s \
  --flake-attempts="${FLAKE_ATTEMPTS}" \
  -nodes="${NODES}" \
  -timeout=2h \
  . stack
