#!/bin/bash
# Re-signs the ad-hoc signed app from `flutter build macos` with Developer ID: nested code inside-out,
# then the app with hardened runtime, a secure timestamp and the entitlements Xcode resolved for the
# Release build (Release.entitlements with build settings expanded). The Xcode project keeps ad-hoc
# signing, so dev and App Store builds are unaffected.
# Usage: SIGNING_IDENTITY=<hash> sign_app.sh <app>
set -euo pipefail
app=${1:?usage: sign_app.sh <app>}
identity=${SIGNING_IDENTITY:?}

entitlements=$(mktemp)
trap 'rm -f "$entitlements"' EXIT
codesign -d --entitlements - --xml "$app" > "$entitlements"
# Xcode's ad-hoc "Sign to Run Locally" adds get-task-allow even in Release; notarization rejects it.
/usr/libexec/PlistBuddy -c 'Delete :com.apple.security.get-task-allow' "$entitlements" 2> /dev/null || true

# -depth lists children before their parents, the order codesign needs. Sparkle (#122) adds XPC services, an
# Updater.app and the bare Autoupdate executable; its Downloader.xpc keeps its own sandbox entitlements.
# ponytail: bare helper executables are listed by name; add the next one here.
find "$app/Contents" -depth \( -name '*.framework' -o -name '*.dylib' -o -name '*.xpc' -o -name '*.app' \
  -o \( -type f -name Autoupdate \) \) -print0 |
  while IFS= read -r -d '' code; do
    codesign --force --options runtime --timestamp --preserve-metadata=entitlements --sign "$identity" "$code"
  done
codesign --force --options runtime --timestamp --sign "$identity" --entitlements "$entitlements" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
