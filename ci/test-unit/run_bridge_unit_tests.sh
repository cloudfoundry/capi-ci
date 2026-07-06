#!/usr/bin/env bash

set -e

service postgresql start

pushd cc-uploader > /dev/null
  CC_UPLOADER_SHA=$(git rev-parse HEAD)
popd > /dev/null

pushd tps > /dev/null
  TPS_SHA=$(git rev-parse HEAD)
popd > /dev/null

# building locket for TPS watcher tests
# locket was moved from a git submodule under src/code.cloudfoundry.org/locket
# to an external Go module (diego-release commit 40a87f2d5). Build it from
# the vendor tree via its Go import path.
pushd diego-release/src/code.cloudfoundry.org > /dev/null
  go build -buildvcs=false -mod=vendor -o /go/bin/locket code.cloudfoundry.org/locket/cmd/locket
popd > /dev/null

pushd capi-release > /dev/null
  source .envrc

  go install github.com/onsi/ginkgo/ginkgo@latest

  pushd src/code.cloudfoundry.org > /dev/null
    pushd cc-uploader > /dev/null
      git fetch
      git checkout "${CC_UPLOADER_SHA}"
      ginkgo -r -keepGoing -p -trace -randomizeAllSpecs -progress --race --flakeAttempts=2 .
    popd > /dev/null

    pushd tps > /dev/null
      git fetch
      git checkout "${TPS_SHA}"
      ginkgo -r -keepGoing -p -trace -randomizeAllSpecs -progress --race --flakeAttempts=2 .
    popd > /dev/null
  popd > /dev/null
popd > /dev/null
