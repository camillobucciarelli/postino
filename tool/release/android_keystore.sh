#!/bin/bash
# Decodes the upload keystore (PKCS12, base64 secret) into $RUNNER_TEMP, readable only by the runner user,
# and exports its path as ANDROID_KEYSTORE_PATH, which android/app/build.gradle.kts reads to sign the
# release. The workflow deletes the file in an `if: always()` step.
set -euo pipefail
: "${ANDROID_KEYSTORE_BASE64:?}" "${RUNNER_TEMP:?}" "${GITHUB_ENV:?}"

keystore="$RUNNER_TEMP/upload-keystore.p12"
(umask 077 && printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 -D > "$keystore")
test -s "$keystore" || { echo "::error::ANDROID_KEYSTORE_BASE64 does not decode to a keystore" >&2; exit 1; }
echo "ANDROID_KEYSTORE_PATH=$keystore" >> "$GITHUB_ENV"
