#!/bin/bash
# Imports the Developer ID p12 into a per-job keychain under $RUNNER_TEMP with a random password, puts it
# first in the user search list and exports SIGNING_IDENTITY (the certificate hash) to later steps.
# keychain_delete.sh undoes all of it. The login keychain is never modified.
set -euo pipefail
: "${MACOS_CERTIFICATE_P12_BASE64:?}" "${MACOS_CERTIFICATE_PASSWORD:?}" "${RUNNER_TEMP:?}" "${GITHUB_ENV:?}"

keychain="$RUNNER_TEMP/release.keychain-db"
saved_list="$RUNNER_TEMP/keychain-search-list"
p12="$RUNNER_TEMP/developer-id.p12"
trap 'rm -f "$p12"' EXIT

password=$(uuidgen)
echo "::add-mask::$password"

# Saved before any change so keychain_delete.sh can restore it; a keychain left by a crashed run is dropped.
security list-keychains -d user | grep -v 'release\.keychain-db' > "$saved_list" || true

(umask 077 && printf '%s' "$MACOS_CERTIFICATE_P12_BASE64" | base64 -D > "$p12")
security create-keychain -p "$password" "$keychain"
# Locks again after 6 h (the job limit): the notarization waits keep the keychain in use for a while.
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$p12" -k "$keychain" -f pkcs12 -P "$MACOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign > /dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" > /dev/null
xargs security list-keychains -d user -s "$keychain" < "$saved_list"

identity=$(security find-identity -v -p codesigning "$keychain" | awk '/"Developer ID Application: / { print $2; exit }')
if [ -z "$identity" ]; then
  # A valid identity needs the "Developer ID Certification Authority" intermediate in the System keychain.
  echo "::error::No valid Developer ID Application identity in the p12 (expired, or intermediate CA missing)" >&2
  exit 1
fi
echo "SIGNING_IDENTITY=$identity" >> "$GITHUB_ENV"
