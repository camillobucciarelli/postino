#!/bin/bash
# Gatekeeper's view of the release: signature, notarization and stapled tickets of the app and the DMG; and the
# keychain access group of the Data Protection keychain (#270), authorized by the embedded profile of the team.
# Usage: APPLE_TEAM_ID=<team> verify.sh <app> <dmg>
set -euo pipefail
app=${1:?usage: verify.sh <app> <dmg>}
dmg=${2:?usage: verify.sh <app> <dmg>}
team=${APPLE_TEAM_ID:?}

codesign --verify --deep --strict --verbose=2 "$app"
spctl --assess --type execute --verbose=2 "$app"
xcrun stapler validate "$app"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
xcrun stapler validate "$dmg"

app_id="$team.$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")"
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
fail() { echo "::error::$1 (#270)" >&2; exit 1; }
# Decoding only: the profile's signature is checked by the system at launch.
security cms -D -i "$app/Contents/embedded.provisionprofile" > "$dir/profile.plist" 2> /dev/null ||
  fail "No embedded.provisionprofile in $app"
codesign -d --entitlements - --xml "$app" > "$dir/entitlements.plist"
is() { [ "$(/usr/libexec/PlistBuddy -c "Print :$2" "$dir/$1.plist" 2> /dev/null)" = "$3" ] || fail "$1 $2 is not $3"; }
is profile TeamIdentifier:0 "$team"
is profile Entitlements:com.apple.application-identifier "$app_id"
is entitlements com.apple.application-identifier "$app_id"
is entitlements com.apple.developer.team-identifier "$team"
is entitlements keychain-access-groups:0 "$app_id"
echo "verify.sh ok"
