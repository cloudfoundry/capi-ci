#!/usr/bin/env bash

set -e

export RUBY_YJIT_ENABLE=1

pushd cloud_controller_ng > /dev/null
  export BUNDLE_GEMFILE=Gemfile
  bundle install
  bundle exec rubocop --parallel
popd > /dev/null
