#!/bin/bash
# Self-check of entitlements_check.sh, run by ci.yml: fake signed entitlements against a fake decoded profile.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
plist() { printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>%s</dict></plist>\n' "$1" > "$2"; }
plist '<key>Entitlements</key><dict>
<key>com.apple.application-identifier</key><string>TEAM.app.postino</string>
<key>com.apple.developer.team-identifier</key><string>TEAM</string>
<key>keychain-access-groups</key><array><string>TEAM.*</string></array>
</dict>' "$tmp/profile.plist"
check() { plist "$1" "$tmp/signed.plist"; tool/release/entitlements_check.sh "$tmp/signed.plist" "$tmp/profile.plist" 2>&1; }
passes() { check "$2" > /dev/null || { echo "should pass: $1"; exit 1; }; }
fails() { # $3: what the error must name
  local out
  if out=$(check "$2"); then echo "should fail: $1"; exit 1; fi
  grep -qF -- "$3" <<< "$out" || { echo "$1: the error does not name $3: $out"; exit 1; }
}
release='<key>com.apple.application-identifier</key><string>TEAM.app.postino</string>
<key>com.apple.developer.team-identifier</key><string>TEAM</string>'
sandbox='<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key><array><string>app.postino-spks</string></array>'

passes "all allowed" "$release<key>keychain-access-groups</key><array><string>TEAM.app.postino</string></array>"
passes "the profile's wildcard covers the group" \
  "$release<key>keychain-access-groups</key><array><string>TEAM.app.postino</string><string>TEAM.other</string></array>"
passes "com.apple.security.* is not in the profile" "$release$sandbox"
fails "group outside the wildcard" "$release<key>keychain-access-groups</key><array><string>OTHER.app.postino</string></array>" \
  'keychain-access-groups = OTHER.app.postino'
fails "other application identifier" '<key>com.apple.application-identifier</key><string>TEAM.app.other</string>' \
  'com.apple.application-identifier = TEAM.app.other'
fails "restricted entitlement missing from the profile" "$release<key>com.apple.developer.icloud-services</key><array><string>CloudKit</string></array>" \
  'entitlement com.apple.developer.icloud-services = CloudKit'
fails "a value echo would take as an option" '<key>com.apple.developer.team-identifier</key><string>-n</string>' \
  'com.apple.developer.team-identifier = -n'
echo "entitlements_check.sh ok"
