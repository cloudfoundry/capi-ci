#!/usr/bin/env bash

set -e

pushd capi-release > /dev/null
  export BUNDLE_GEMFILE=spec/Gemfile
  bundle install

  bundle exec rspec spec
popd > /dev/null
