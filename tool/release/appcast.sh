#!/bin/bash
# Writes the Sparkle appcast (#122) of a notarized DMG: one item whose enclosure is <download url prefix><dmg name>,
# sparkle:version and sparkle:shortVersionString read from the app inside (CFBundleVersion, X.Y.Z), the DMG's
# EdDSA signature and, since the app sets SURequireSignedFeed, the feed's own. Then checks the result as Sparkle
# would: a feed that does not verify never leaves the job.
# The private key goes from SPARKLE_ED_PRIVATE_KEY to the tools' stdin: never on disk, never in argv.
# Sparkle's tools come from the SwiftPM artifact `flutter build macos` resolved; SPARKLE_BIN overrides.
# Usage: SPARKLE_ED_PRIVATE_KEY=<key> appcast.sh <dmg> <download url prefix> <appcast out>
set -euo pipefail
dmg=${1:?usage: appcast.sh <dmg> <download url prefix> <appcast out>}
prefix=${2:?usage: appcast.sh <dmg> <download url prefix> <appcast out>}
out=${3:?usage: appcast.sh <dmg> <download url prefix> <appcast out>}
if [ -z "${SPARKLE_ED_PRIVATE_KEY:-}" ]; then
  echo "::error::SPARKLE_ED_PRIVATE_KEY is not set" >&2
  exit 1
fi
bin=${SPARKLE_BIN:-build/macos/SourcePackages/artifacts/sparkle/Sparkle/bin}
key() { printf '%s' "$SPARKLE_ED_PRIVATE_KEY"; }

# A folder with this DMG alone: generate_appcast lists every archive it finds there.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$dmg" "$work/"
key | "$bin/generate_appcast" --ed-key-file - --download-url-prefix "$prefix" -o "$work/appcast.xml" "$work"

grep -q "url=\"$prefix$(basename "$dmg")\"" "$work/appcast.xml" || { echo "::error::Appcast enclosure is not $prefix$(basename "$dmg")" >&2; exit 1; }
grep -q 'sparkle-signatures' "$work/appcast.xml" || { echo "::error::Appcast is not signed (SURequireSignedFeed)" >&2; exit 1; }
key | "$bin/sign_update" --verify --ed-key-file - "$work/appcast.xml"
signature=$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' "$work/appcast.xml")
# generate_appcast only warns, and leaves the DMG unsigned, when the key is not the app's SUPublicEDKey.
test -n "$signature" || { echo "::error::DMG not signed: SPARKLE_ED_PRIVATE_KEY does not match SUPublicEDKey?" >&2; exit 1; }
key | "$bin/sign_update" --verify --ed-key-file - "$dmg" "$signature"
cp "$work/appcast.xml" "$out"
