#!/bin/bash
#
# Weekly OpenAPI traffic recorder.
#
# Runs the CAPI compliance suite against a claimed bosh-lite with HAR capture
# enabled, producing a deduplicated corpus of real request/response pairs.
# Future spec changes replay against that corpus in seconds rather than
# needing another hour-long suite run and a live foundation.
#
# Deliberately exits 0 even when the suite fails: a BARA flake must not cost us
# the corpus, and this job gates nothing.

set -u
set -o pipefail

ROOT="$(pwd)"
REPORT_DIR="${ROOT}/compliance-report"
# Defaulted here as well as in the task params so the script stays runnable by
# hand under `set -u`.
TEST_SUITE="${TEST_SUITE:-capi-bara-tests}"
OPENAPI_DIR="${ROOT}/cloud-controller-ng/docs/openapi"

mkdir -p "${REPORT_DIR}"

# ── Target the claimed bosh-lite ─────────────────────────────────────────────

ENV_NAME="$(cat "${ROOT}/bosh-lite-env/name" 2>/dev/null || echo unknown)"
echo "Claimed bosh-lite: ${ENV_NAME}"

# The pool file is a shell script of BOSH_* / CREDHUB_* exports, as written by
# ci/bosh-lite/create-env-vars-file.sh.
# shellcheck disable=SC1091
source "${ROOT}/bosh-lite-env/metadata"

if [ -z "${BOSH_LITE_DOMAIN:-}" ]; then
  echo "ERROR: BOSH_LITE_DOMAIN missing from bosh-lite-env/metadata" >&2
  exit 1
fi

export CF_API_URL="https://api.${BOSH_LITE_DOMAIN}"
export CF_APPS_DOMAIN="${BOSH_LITE_DOMAIN}"
export CF_ADMIN_USER=admin

# CREDHUB_CA_CERT holds certificate *contents*, but the CLI wants a file path.
if [ -n "${CREDHUB_CA_CERT:-}" ] && [ ! -f "${CREDHUB_CA_CERT}" ]; then
  printf '%s' "${CREDHUB_CA_CERT}" > /tmp/credhub-ca.crt
  CREDHUB_CA_CERT_FILE=/tmp/credhub-ca.crt
else
  CREDHUB_CA_CERT_FILE="${CREDHUB_CA_CERT:-}"
fi

echo "Logging in to CredHub at ${CREDHUB_SERVER}..."
credhub api --server "${CREDHUB_SERVER}" ${CREDHUB_CA_CERT_FILE:+--ca-cert "${CREDHUB_CA_CERT_FILE}"}
credhub login --client-name "${CREDHUB_CLIENT}" --client-secret "${CREDHUB_SECRET}"

CF_ADMIN_PASSWORD="$(credhub get --name "${CF_ADMIN_PASSWORD_CREDHUB_PATH}" --output-json | jq -r '.value')"
export CF_ADMIN_PASSWORD
if [ -z "${CF_ADMIN_PASSWORD}" ] || [ "${CF_ADMIN_PASSWORD}" = "null" ]; then
  echo "ERROR: could not read ${CF_ADMIN_PASSWORD_CREDHUB_PATH} from CredHub" >&2
  exit 1
fi

# ── Record ───────────────────────────────────────────────────────────────────

export THREADS
export TEST_SUITE
export HAR_CAPTURE=1
export HAR_FILE="${REPORT_DIR}/traffic.har"
export HAR_MAX_PER_KEY
export HAR_MAX_BODY_BYTES

cd "${OPENAPI_DIR}"

echo "Installing spec toolchain..."
yarn install --frozen-lockfile --non-interactive --network-timeout 600000

# test-compliance.js clones the suite itself; hand it the version this job
# resolved so the pipeline controls the ref rather than the script.
mkdir -p .tmp
if [ -d "${ROOT}/acceptance-tests" ]; then
  echo "Seeding .tmp/${TEST_SUITE} from the pipeline's resource..."
  rm -rf ".tmp/${TEST_SUITE}"
  cp -r "${ROOT}/acceptance-tests" ".tmp/${TEST_SUITE}"
fi

echo "Running compliance suite against ${CF_API_URL} with HAR capture..."
set +e
yarn test:compliance
SUITE_EXIT=$?
set -e
echo "Compliance suite exited ${SUITE_EXIT}"

# ── Publish ──────────────────────────────────────────────────────────────────

cp -f "out/${TEST_SUITE}.log" "${REPORT_DIR}/" 2>/dev/null || true
cp -f "out/${TEST_SUITE}-error.log" "${REPORT_DIR}/" 2>/dev/null || true
cp -rf out/logs "${REPORT_DIR}/" 2>/dev/null || true

if [ -s out/wiretap-report.json ]; then
  echo "Summarising violations..."
  node bin/summarize-violations.js out/wiretap-report.json --json \
    > "${REPORT_DIR}/summary.json" || true
  node bin/summarize-violations.js out/wiretap-report.json --fields --top 40 \
    | tee "${REPORT_DIR}/violations.md" || true

  # wiretap >=0.7 inlines the whole rendered schema per validation error, which
  # makes the raw report gigabytes. Nothing downstream reads it.
  echo "Trimming referenceSchema from the raw report..."
  node -e '
    const fs = require("fs");
    const f = "out/wiretap-report.json";
    const d = JSON.parse(fs.readFileSync(f, "utf8"));
    const list = Array.isArray(d) ? d : [d];
    for (const r of list) for (const e of (r.validationErrors || [])) delete e.referenceSchema;
    fs.writeFileSync(f, JSON.stringify(list));
  ' || true
  gzip -c out/wiretap-report.json > "${REPORT_DIR}/wiretap-report.json.gz" || true
else
  echo "No wiretap report produced."
fi

if [ -s "${HAR_FILE}" ]; then
  STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  gzip -c "${HAR_FILE}" > "${REPORT_DIR}/traffic-${STAMP}.har.gz"
  rm -f "${HAR_FILE}"
  echo "HAR corpus: ${REPORT_DIR}/traffic-${STAMP}.har.gz ($(du -h "${REPORT_DIR}/traffic-${STAMP}.har.gz" | cut -f1))"
  echo "  entries: $(gzip -dc "${REPORT_DIR}/traffic-${STAMP}.har.gz" | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      try { console.log(JSON.parse(s).log.entries.length); } catch (_) { console.log("unknown"); }
    });
  ')"
else
  # Without a corpus the `put` has nothing to upload, which would fail the job
  # after the fact. Fail loudly here instead.
  echo "ERROR: no HAR produced at ${HAR_FILE} — nothing to publish" >&2
  exit 1
fi

echo "Done (suite exit was ${SUITE_EXIT}; not failing the job)."
exit 0
