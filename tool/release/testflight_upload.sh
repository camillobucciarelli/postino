#!/bin/bash
# Uploads an IPA to App Store Connect (TestFlight) with the API key. altool reads AuthKey_<id>.p8 from
# API_PRIVATE_KEYS_DIR, a temporary directory deleted on exit. App Store Connect refuses a build number already
# uploaded for the version, so a rerun of a released version fails here: that is the only duplicate guard.
# Usage: testflight_upload.sh <ipa>
set -euo pipefail
ipa=${1:?usage: testflight_upload.sh <ipa>}
: "${APP_STORE_CONNECT_API_KEY_BASE64:?}" "${APP_STORE_CONNECT_KEY_ID:?}" "${APP_STORE_CONNECT_ISSUER_ID:?}"
[ -f "$ipa" ] || { echo "::error::No IPA at $ipa" >&2; exit 1; }

keys=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/asc-key.XXXXXX")
# A cancelled job gets SIGTERM, which skips an EXIT-only trap: the decoded key must not outlive the run.
trap 'rm -rf "$keys"' EXIT
trap 'exit 1' HUP INT TERM
(umask 077 && printf '%s' "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 -D > "$keys/AuthKey_$APP_STORE_CONNECT_KEY_ID.p8")
API_PRIVATE_KEYS_DIR=$keys xcrun altool --upload-app -t ios -f "$ipa" \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
