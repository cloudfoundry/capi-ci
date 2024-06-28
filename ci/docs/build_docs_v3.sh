#!/usr/bin/env bash

set -e

if [[ $# -ne 3 ]]; then
  echo "You need to provide the following arguments:"
  echo "1. The version number to publish"
  echo "2. The directory containing the docs sources"
  echo "3. The directory containing the published docs"
  exit 1
fi

readonly VERSION=$1
readonly DOCS_DIR=$2
readonly GH_PAGES_DIR=$3

function abort_on_existing_version() {
  pushd "${GH_PAGES_DIR}" > /dev/null
    if [[ ${VERSION} != 'release-candidate' && -d "version/${VERSION}" ]]; then
      echo "That version already exists."
      exit 1
    fi
  popd > /dev/null
}

function build_docs() {
  pushd "${DOCS_DIR}" > /dev/null
    export BUNDLE_GEMFILE=Gemfile

    bundle install

    touch source/versionfile
    echo "${VERSION}" > source/versionfile

    bundle exec middleman build

    rm -f source/versionfile
  popd > /dev/null
}

function add_new_docs() {
  pushd "${GH_PAGES_DIR}" > /dev/null
    if [[ ${VERSION} == 'release-candidate' ]]; then
      rm -rf version/release-candidate
    fi

    mkdir -p "version/${VERSION}"
    cp -r ${DOCS_DIR}/build/* "version/${VERSION}"
  popd > /dev/null
}

function update_index_html() {
  pushd "${GH_PAGES_DIR}" > /dev/null
    if [[ ${VERSION} != 'release-candidate' ]]; then
      cat <<INDEX > index.html
<!DOCTYPE html>
<html>
<head>
  <link rel="canonical" href="/version/${VERSION}/index.html"/>
  <meta http-equiv="content-type" content="text/html; charset=utf-8" />
  <meta http-equiv="refresh" content="0;url=/version/${VERSION}/index.html" />
  <script>
    var hash = location.hash || '';
    location = '/version/${VERSION}/index.html' + hash;
  </script>
</head>
<body>
  <h1>Redirecting...</h1>
  <a id="redirect-link" href="/version/${VERSION}/index.html">Click here if you are not redirected.</a>
</body>
</html>
INDEX
    fi
  popd > /dev/null
}

function write_versions_json() {
  pushd "${GH_PAGES_DIR}" > /dev/null
    # list of sorted directories (excluding 'alpha')
    local versions=$(ls version | grep -v alpha | sort --version-sort -r)

    local versions_json=$(echo "$versions" | awk '{print "\t\t\""$0"\","}' | sed '$ s/,$//')

    cat <<-EOF > versions.json
{
\t"versions": [
$versions_json
\t]
}
EOF
  popd > /dev/null
}

function main() {
  abort_on_existing_version
  build_docs
  add_new_docs
  update_index_html
  write_versions_json
}

main
