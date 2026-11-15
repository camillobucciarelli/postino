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
# A Development profile passes notarization and spctl too, then the app does not launch on any other Mac.
is profile ProvisionsAllDevices true
# An expired profile no longer authorizes the app's restricted entitlements: it would not launch.
expires=$(plutil -extract ExpirationDate raw -o - "$dir/profile.plist")
[[ $expires > $(date -u +%Y-%m-%dT%H:%M:%SZ) ]] || fail "The provisioning profile expired on $expires"
is profile Entitlements:com.apple.application-identifier "$app_id"
group=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:keychain-access-groups:0' "$dir/profile.plist" 2> /dev/null) ||
  fail "The profile authorizes no keychain access group"
# shellcheck disable=SC2053 # the profile's group is a pattern, usually <team>.*
[[ $app_id == $group ]] || fail "The profile's keychain access group $group does not cover $app_id"
# The profile authorizes certain certificates: one signed with another passes notarization, then is killed at launch.
codesign -d --extract-certificates="$dir/cert" "$app" 2> /dev/null
leaf=$(base64 -i "$dir/cert0" | tr -d '\n')
plutil -extract DeveloperCertificates xml1 -o - "$dir/profile.plist" | tr -d ' \t\n' | grep -qF "$leaf" ||
  fail "The profile does not authorize the certificate that signed $app"
is entitlements com.apple.application-identifier "$app_id"
is entitlements com.apple.developer.team-identifier "$team"
is entitlements keychain-access-groups:0 "$app_id"
"$(dirname "$0")/entitlements_check.sh" "$dir/entitlements.plist" "$dir/profile.plist"
echo "verify.sh ok"
