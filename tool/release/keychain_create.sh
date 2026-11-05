#!/bin/bash
# Imports the Developer ID p12 into a per-job keychain under $RUNNER_TEMP with a random password, puts it
# first in the user search list and exports SIGNING_IDENTITY (the certificate hash) to later steps.
# keychain_delete.sh undoes all of it. The login keychain is never modified.
set -euo pipefail
: "${MACOS_CERTIFICATE_P12_BASE64:?}" "${MACOS_CERTIFICATE_PASSWORD:?}" "${APPLE_TEAM_ID:?}"
: "${RUNNER_TEMP:?}" "${GITHUB_ENV:?}"

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
# ponytail: `security` takes passwords only as arguments (visible to `ps` on the runner for the call's
# duration); the keychain password is single-use and the p12 file is gone when this script ends.
security import "$p12" -k "$keychain" -f pkcs12 -P "$MACOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign > /dev/null
# Apple's public Developer ID G2 intermediate (www.apple.com/certificateauthority): macOS ships only G1, and
# without G2 the identity is not valid. Fetched from Apple, chain checked against the system Apple Root CA.
# A p12 exported with its chain already brings it, and a second import fails as a duplicate.
security find-certificate -a -Z "$keychain" | grep 5B45F61068B29FCC8FFFF1A7E99B78DA9E9C4635 > /dev/null ||
  security import "$(dirname "$0")/DeveloperIDG2CA.cer" -k "$keychain" > /dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" > /dev/null
xargs security list-keychains -d user -s "$keychain" < "$saved_list"
# The user's trustd agent caches the search list, so codesign (which builds the chain through trustd) would
# not see the G2 intermediate above and fail with errSecInternalComponent. launchd restarts it on demand.
pkill -U "$(id -u)" -x trustd || [ $? -eq 1 ] # 1: no agent running

identity=$(security find-identity -v -p codesigning "$keychain" | 
  awk -v team="($APPLE_TEAM_ID)\"" 'index($0, "\"Developer ID Application: ") && index($0, team) { print $2; exit }')
if [ -z "$identity" ]; then
  echo "::error::No valid Developer ID Application identity of team $APPLE_TEAM_ID in the p12 (wrong team, expired, or intermediate CA missing)" >&2
  exit 1
fi
echo "SIGNING_IDENTITY=$identity" >> "$GITHUB_ENV"
