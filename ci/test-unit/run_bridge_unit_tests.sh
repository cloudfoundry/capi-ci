#!/usr/bin/env bash

set -e

service postgresql start

pushd cc-uploader
  CC_UPLOADER_SHA=$(git rev-parse HEAD)
popd

pushd tps
  TPS_SHA=$(git rev-parse HEAD)
popd

# building locket for TPS watcher tests
pushd diego-release/src/code.cloudfoundry.org
  go build -buildvcs=false -o /go/bin/locket ./locket/cmd/locket
popd

pushd capi-release
  source .envrc

  go install github.com/onsi/ginkgo/ginkgo@latest

  pushd src/code.cloudfoundry.org
    pushd cc-uploader
      git fetch
      git checkout "${CC_UPLOADER_SHA}"
      ginkgo -r -keepGoing -p -trace -randomizeAllSpecs -progress --race .
    popd

    pushd tps
      git fetch
      git checkout "${TPS_SHA}"
      ginkgo -r -keepGoing -p -trace -randomizeAllSpecs -progress --race .
    popd
  popd
popd
