#!/bin/bash

set -e

PROTO_SRC=$(mktemp -d)
git clone https://github.com/gogo/protobuf.git "$PROTO_SRC/github.com/gogo/protobuf"

RUBY_OUT=$(mktemp -d)

pushd bbs-models > /dev/null
  sed -i'' -e 's/package models/package diego.bbs.models/' models/*.proto
  protoc --proto_path="$PROTO_SRC":models --ruby_out="$RUBY_OUT" models/*.proto
popd > /dev/null

cp -r "$RUBY_OUT/." cloud_controller_ng/lib/diego/bbs/models

pushd cloud_controller_ng > /dev/null
  git config user.name "ari-wg-gitbot"
  git config user.email "app-runtime-interfaces@cloudfoundry.org"
  git add .
  git commit --allow-empty -m "Bump BBS protos"
popd > /dev/null

cp -r cloud_controller_ng/. updated-bbs-protos
