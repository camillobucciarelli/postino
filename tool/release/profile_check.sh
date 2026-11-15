#!/bin/bash
# The embedded provisioning profile of a signed app and the entitlements it carries (#270): the team's, of the right
# kind, not expired, for the app's identifier, authorizing the keychain access group of the Data Protection keychain,
# the certificate that signed the app and every restricted entitlement (entitlements_check.sh).
# The kind: developer-id provisions all devices; app-store (the Mac App Store, #325) names none. A Development profile
# names devices: it passes notarization and spctl, then the app launches on no other Mac.
# Given a directory instead of an app, it checks what it holds as the app would give it: Info.plist, profile.plist
# (decoded), entitlements.plist and cert0 (the signing certificate, DER), as profile_check_test.sh does.
# Usage: APPLE_TEAM_ID=<team> profile_check.sh <app|dir> <developer-id|app-store>
set -euo pipefail
app=${1:?usage: profile_check.sh <app|dir> <developer-id|app-store>}
kind=${2:?usage: profile_check.sh <app|dir> <developer-id|app-store>}
team=${APPLE_TEAM_ID:?}
fail() { echo "::error::$1 (#270)" >&2; exit 1; }

if [ -d "$app/Contents" ]; then
  dir=$(mktemp -d)
  trap 'rm -rf "$dir"' EXIT
  cp "$app/Contents/Info.plist" "$dir/Info.plist"
  # Decoding only: the profile's signature is checked by the system at launch.
  security cms -D -i "$app/Contents/embedded.provisionprofile" > "$dir/profile.plist" 2> /dev/null ||
    fail "No embedded.provisionprofile in $app"
  codesign -d --entitlements - --xml "$app" > "$dir/entitlements.plist"
  codesign -d --extract-certificates="$dir/cert" "$app" 2> /dev/null
else
  dir=$app
fi
app_id="$team.$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$dir/Info.plist")"
is() { [ "$(/usr/libexec/PlistBuddy -c "Print :$2" "$dir/$1.plist" 2> /dev/null)" = "$3" ] || fail "$1 $2 is not $3"; }
lacks() { ! /usr/libexec/PlistBuddy -c "Print :$1" "$dir/profile.plist" > /dev/null 2>&1 || fail "The profile has $1: not a $kind profile"; }
is profile TeamIdentifier:0 "$team"
case $kind in
  developer-id) is profile ProvisionsAllDevices true ;;
  app-store) lacks ProvisionsAllDevices && lacks ProvisionedDevices ;;
  *) fail "Not developer-id or app-store: $kind" ;;
esac
# An expired profile no longer authorizes the app's restricted entitlements: it would not launch.
expires=$(plutil -extract ExpirationDate raw -o - "$dir/profile.plist")
[[ $expires > $(date -u +%Y-%m-%dT%H:%M:%SZ) ]] || fail "The provisioning profile expired on $expires"
is profile Entitlements:com.apple.application-identifier "$app_id"
group=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:keychain-access-groups:0' "$dir/profile.plist" 2> /dev/null) ||
  fail "The profile authorizes no keychain access group"
# shellcheck disable=SC2053 # the profile's group is a pattern, usually <team>.*
[[ $app_id == $group ]] || fail "The profile's keychain access group $group does not cover $app_id"
# The profile authorizes certain certificates: one signed with another passes notarization, then is killed at launch.
leaf=$(base64 -i "$dir/cert0" | tr -d '\n')
plutil -extract DeveloperCertificates xml1 -o - "$dir/profile.plist" | tr -d ' \t\n' | grep -qF "$leaf" ||
  fail "The profile does not authorize the certificate that signed the app"
is entitlements com.apple.application-identifier "$app_id"
is entitlements com.apple.developer.team-identifier "$team"
is entitlements keychain-access-groups:0 "$app_id"
"$(dirname "$0")/entitlements_check.sh" "$dir/entitlements.plist" "$dir/profile.plist"
echo "profile_check.sh ok"
