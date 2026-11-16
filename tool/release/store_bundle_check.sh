#!/bin/bash
# The Mac App Store variant (#325, ADR 0021) is a bundle the Store accepts and updates by itself: no Sparkle (framework,
# link, SU* keys or the mach-lookup exceptions of its installer, which App Review rejects), the App Sandbox on, the
# category, the encryption answer of ADR 0022 and the privacy manifests (the app's, sqlcipher's and cnativeapi's).
# Runs on any signed build of the variant: ci.yml checks the ad-hoc signed one, verify_store.sh the release.
# Usage: store_bundle_check.sh <app>
set -euo pipefail
app=${1:?usage: store_bundle_check.sh <app>}
fail() { echo "::error::$1 (#325)" >&2; exit 1; }
plist="$app/Contents/Info.plist"
[ -f "$plist" ] || fail "No Info.plist in $app"
value() { /usr/libexec/PlistBuddy -c "Print :$1" "$2" 2> /dev/null; }
# plutil's XML puts top-level keys at one tab of indentation.
keys() { plutil -convert xml1 -o - "$1" | sed -n 's/^\t<key>\(.*\)<\/key>$/\1/p'; }

# Sparkle's framework and the helpers inside it; Flutter's own ink_sparkle shader is no Sparkle.
sparkle=$(find "$app" \( -name Sparkle.framework -o -name Autoupdate -o -name Updater.app -o -name Installer.xpc \
  -o -name Downloader.xpc \) -print -quit)
[ -z "$sparkle" ] || fail "Sparkle in the bundle: ${sparkle#"$app"/}"
executable="$app/Contents/MacOS/$(value CFBundleExecutable "$plist")"
# Read first: an otool failure must not pass for "no Sparkle".
links=$(otool -L "$executable") || fail "otool cannot read $executable"
! grep -qi sparkle <<< "$links" || fail "$executable links Sparkle"
su=$(keys "$plist" | grep '^SU' | paste -sd , -) || true
[ -z "$su" ] || fail "Sparkle keys in Info.plist: $su"
[ "$(value LSApplicationCategoryType "$plist")" = public.app-category.productivity ] ||
  fail "LSApplicationCategoryType is not public.app-category.productivity"
# ADR 0022: exempt from providing documentation (France excluded), not "no encryption". true needs the code of an
# approved document, which Postino has not: App Store Connect rejects the upload (90592), as it does an empty code.
[ "$(value ITSAppUsesNonExemptEncryption "$plist")" = false ] || fail "ITSAppUsesNonExemptEncryption is not false (ADR 0022)"
code=$(keys "$plist" | grep -x ITSEncryptionExportComplianceCode) || true
[ -z "$code" ] || fail "ITSEncryptionExportComplianceCode in Info.plist without an approved document (ADR 0022)"
for manifest in Resources/PrivacyInfo.xcprivacy Frameworks/{sqlcipher,cnativeapi}.framework/Resources/PrivacyInfo.xcprivacy; do
  manifest="$app/Contents/$manifest"
  plutil -lint -s "$manifest" 2> /dev/null || fail "No valid privacy manifest at ${manifest#"$app"/}"
done

entitlements=$(mktemp)
trap 'rm -f "$entitlements"' EXIT
codesign -d --entitlements - --xml "$app" > "$entitlements" 2> /dev/null || fail "$app is not signed"
[ "$(value com.apple.security.app-sandbox "$entitlements")" = true ] || fail "The App Sandbox is off"
lookup=$(keys "$entitlements" | grep 'mach-lookup' | paste -sd , -) || true
[ -z "$lookup" ] || fail "Sparkle's mach-lookup exceptions in the entitlements: $lookup"
echo "store_bundle_check.sh ok"
