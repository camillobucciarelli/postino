#!/bin/bash
# Packs the app into a compressed DMG with an Applications link for drag-and-drop install, then signs it.
# Usage: SIGNING_IDENTITY=<hash> make_dmg.sh <app> <dmg>
set -euo pipefail
app=${1:?usage: make_dmg.sh <app> <dmg>}
dmg=${2:?usage: make_dmg.sh <app> <dmg>}
identity=${SIGNING_IDENTITY:?}

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/$(basename "$app")"
ln -s /Applications "$staging/Applications"
mkdir -p "$(dirname "$dmg")"
hdiutil create -volname Postino -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg"
codesign --force --timestamp --sign "$identity" "$dmg"
