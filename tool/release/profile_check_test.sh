#!/bin/bash
# Self-check of profile_check.sh, run by ci.yml: what a signed app gives it (Info.plist, decoded profile, entitlements,
# signing certificate) faked in a directory, for the Developer ID profile of the DMG and the Mac App Store one (#325).
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
plist() { printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>%s</dict></plist>\n' "$1" > "$2"; }
printf 'the signing certificate' > "$tmp/cert0"
cert=$(base64 -i "$tmp/cert0")
plist '<key>CFBundleIdentifier</key><string>app.postino</string>' "$tmp/Info.plist"
granted='<key>com.apple.application-identifier</key><string>TEAM.app.postino</string>
<key>com.apple.developer.team-identifier</key><string>TEAM</string>
<key>keychain-access-groups</key><array><string>TEAM.*</string></array>'
signed='<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.application-identifier</key><string>TEAM.app.postino</string>
<key>com.apple.developer.team-identifier</key><string>TEAM</string>
<key>keychain-access-groups</key><array><string>TEAM.app.postino</string></array>'
future=$(date -u -v+1y +%Y-%m-%dT%H:%M:%SZ)
# profile <devices> [expiration] [certificate] [entitlements]: the decoded profile.
profile() {
  plist "<key>TeamIdentifier</key><array><string>TEAM</string></array>$1
<key>ExpirationDate</key><date>${2:-$future}</date>
<key>DeveloperCertificates</key><array><data>${3:-$cert}</data></array>
<key>Entitlements</key><dict>${4:-$granted}</dict>" "$tmp/profile.plist"
}
check() { plist "${2:-$signed}" "$tmp/entitlements.plist"; APPLE_TEAM_ID=TEAM tool/release/profile_check.sh "$tmp" "$1" 2>&1; }
passes() { check "$2" > /dev/null || { echo "should pass: $1: $(check "$2")"; exit 1; }; }
fails() { # <case> <kind> <what the error must name> [signed entitlements]
  local out
  if out=$(check "$2" "${4:-}"); then echo "should fail: $1"; exit 1; fi
  grep -qF -- "$3" <<< "$out" || { echo "$1: the error does not name $3: $out"; exit 1; }
}
all='<key>ProvisionsAllDevices</key><true/>'
devices='<key>ProvisionedDevices</key><array><string>00008103-001</string></array>'

profile "$all"
passes "Developer ID profile" developer-id
fails "Developer ID profile for the Store" app-store 'ProvisionsAllDevices'
profile ''
passes "Mac App Store profile" app-store
fails "Mac App Store profile for the DMG" developer-id 'ProvisionsAllDevices'
profile "$devices"
fails "Development profile for the Store" app-store 'ProvisionedDevices'
fails "Development profile for the DMG" developer-id 'ProvisionsAllDevices'
fails "unknown kind" testflight 'Not developer-id or app-store'
profile '' 2020-01-01T00:00:00Z
fails "expired profile" app-store 'expired'
profile '' '' "$(printf 'another certificate' | base64)"
fails "certificate not in the profile" app-store 'does not authorize the certificate'
profile '' '' '' "${granted/TEAM.\*/TEAM.other}"
fails "keychain group not covered" app-store 'does not cover TEAM.app.postino'
profile ''
fails "signed with another keychain group" app-store 'keychain-access-groups:0 is not TEAM.app.postino' \
  "${signed/<string>TEAM.app.postino<\/string><\/array>/<string>TEAM.app.other</string></array>}"
fails "restricted entitlement outside the profile" app-store 'com.apple.developer.icloud-services' \
  "$signed<key>com.apple.developer.icloud-services</key><array><string>CloudKit</string></array>"
echo "profile_check.sh ok"
