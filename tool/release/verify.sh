#!/bin/bash
# Gatekeeper's view of the release: signature, notarization and stapled tickets of the app and the DMG.
# Usage: verify.sh <app> <dmg>
set -euo pipefail
app=${1:?usage: verify.sh <app> <dmg>}
dmg=${2:?usage: verify.sh <app> <dmg>}

codesign --verify --deep --strict --verbose=2 "$app"
spctl --assess --type execute --verbose=2 "$app"
xcrun stapler validate "$app"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
xcrun stapler validate "$dmg"
