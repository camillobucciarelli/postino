#!/bin/bash
# Re-signs the ad-hoc signed app from `flutter build macos` with Developer ID: nested code inside-out,
# then the app with hardened runtime, a secure timestamp and the entitlements Xcode resolved for the
# Release build (Release.entitlements with build settings expanded). The Xcode project keeps ad-hoc
# signing, so dev and App Store builds are unaffected.
# The app also gets the Developer ID provisioning profile and the entitlements it authorizes, the app's
# keychain access group: the database key lives in the Data Protection keychain, which needs it (#270).
# Usage: SIGNING_IDENTITY=<hash> APPLE_TEAM_ID=<team> PROVISION_PROFILE=<file> sign_app.sh <app>
set -euo pipefail
app=${1:?usage: sign_app.sh <app>}
identity=${SIGNING_IDENTITY:?}
team=${APPLE_TEAM_ID:?}
profile=${PROVISION_PROFILE:?the Developer ID provisioning profile (#270)}
test -s "$profile" || { echo "::error::No provisioning profile at $profile" >&2; exit 1; }
app_id="$team.$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")"

entitlements=$(mktemp)
trap 'rm -f "$entitlements"' EXIT
codesign -d --entitlements - --xml "$app" > "$entitlements"
# Xcode's ad-hoc "Sign to Run Locally" adds get-task-allow even in Release; notarization rejects it.
/usr/libexec/PlistBuddy -c 'Delete :com.apple.security.get-task-allow' "$entitlements" 2> /dev/null || true
for key in com.apple.application-identifier com.apple.developer.team-identifier keychain-access-groups; do
  /usr/libexec/PlistBuddy -c "Delete :$key" "$entitlements" 2> /dev/null || true
done
/usr/libexec/PlistBuddy \
  -c "Add :com.apple.application-identifier string $app_id" \
  -c "Add :com.apple.developer.team-identifier string $team" \
  -c 'Add :keychain-access-groups array' \
  -c "Add :keychain-access-groups:0 string $app_id" \
  "$entitlements"
cp "$profile" "$app/Contents/embedded.provisionprofile"

# -depth lists children before their parents, the order codesign needs. Sparkle (#122) adds XPC services, an
# Updater.app and the bare Autoupdate executable. Nested code gets no entitlements: Autoupdate ships with an
# unprefixed application-identifier that Developer ID must not carry, and Downloader.xpc (unused: the app has
# network.client) ships with none.
# ponytail: bare helper executables are listed by name; add the next one here.
find "$app/Contents" -depth \( -name '*.framework' -o -name '*.dylib' -o -name '*.xpc' -o -name '*.app' \
  -o \( -type f -name Autoupdate \) \) -print0 |
  while IFS= read -r -d '' code; do
    codesign --force --options runtime --timestamp --sign "$identity" "$code"
  done
codesign --force --options runtime --timestamp --sign "$identity" --entitlements "$entitlements" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
