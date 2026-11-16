#!/bin/bash
# Gatekeeper's view of the release: signature, notarization and stapled tickets of the app and the DMG; and the
# Developer ID provisioning profile with the keychain access group of the Data Protection keychain (#270).
# Usage: APPLE_TEAM_ID=<team> verify.sh <app> <dmg>
set -euo pipefail
app=${1:?usage: verify.sh <app> <dmg>}
dmg=${2:?usage: verify.sh <app> <dmg>}
: "${APPLE_TEAM_ID:?}"

codesign --verify --deep --strict --verbose=2 "$app"
spctl --assess --type execute --verbose=2 "$app"
xcrun stapler validate "$app"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
xcrun stapler validate "$dmg"
"$(dirname "$0")/profile_check.sh" "$app" developer-id
echo "verify.sh ok"
