#!/bin/bash
# Self-check of store_bundle_check.sh, run by ci.yml: a fake ad-hoc signed bundle that passes, then one defect at a time.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
manifest='<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>NSPrivacyTracking</key><false/></dict></plist>'
sandbox='<key>com.apple.security.app-sandbox</key><true/>'
plist_keys='<key>CFBundleExecutable</key><string>Postino</string>
<key>CFBundleIdentifier</key><string>app.postino.test</string>
<key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
<key>ITSAppUsesNonExemptEncryption</key><true/>'

# app <Info.plist keys> <entitlements keys>: a fresh bundle at $tmp/Postino.app, signed ad hoc.
app() {
  local a="$tmp/Postino.app"
  rm -rf "$a"
  mkdir -p "$a/Contents/MacOS" "$a/Contents/Resources"
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>%s</dict></plist>\n' "$1" > "$a/Contents/Info.plist"
  cp /usr/bin/true "$a/Contents/MacOS/Postino"
  echo "$manifest" > "$a/Contents/Resources/PrivacyInfo.xcprivacy"
  # Versioned frameworks codesign accepts as nested code, with their manifests.
  for fw in sqlcipher cnativeapi; do
    local f="$a/Contents/Frameworks/$fw.framework"
    mkdir -p "$f/Versions/A/Resources"
    cp /usr/bin/true "$f/Versions/A/$fw"
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict><key>CFBundleExecutable</key><string>%s</string><key>CFBundlePackageType</key><string>FMWK</string></dict></plist>\n' \
      "$fw" > "$f/Versions/A/Resources/Info.plist"
    echo "$manifest" > "$f/Versions/A/Resources/PrivacyInfo.xcprivacy"
    ln -s A "$f/Versions/Current"
    ln -s Versions/Current/Resources "$f/Resources"
    ln -s "Versions/Current/$fw" "$f/$fw"
    codesign --force --sign - "$f" 2> /dev/null
  done
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>%s</dict></plist>\n' "$2" > "$tmp/e.plist"
  sign
}
sign() { codesign --force --sign - --entitlements "$tmp/e.plist" "$tmp/Postino.app" 2> /dev/null; }
check() { tool/release/store_bundle_check.sh "$tmp/Postino.app" 2>&1; }
fails() { # <case> <what the error must name>; the bundle is already built
  local out
  if out=$(check); then echo "should fail: $1"; exit 1; fi
  grep -qF -- "$2" <<< "$out" || { echo "$1: the error does not name $2: $out"; exit 1; }
}

app "$plist_keys" "$sandbox"
check > /dev/null || { echo "should pass: $(check)"; exit 1; }
# Flutter's own shader is named ink_sparkle: no Sparkle.
mkdir -p "$tmp/Postino.app/Contents/Resources/shaders" && : > "$tmp/Postino.app/Contents/Resources/shaders/ink_sparkle.frag"
sign
check > /dev/null || { echo "ink_sparkle should pass: $(check)"; exit 1; }

app "$plist_keys" "$sandbox"
mkdir -p "$tmp/Postino.app/Contents/Frameworks/Sparkle.framework"
fails "Sparkle framework" 'Contents/Frameworks/Sparkle.framework'
app "$plist_keys<key>SUFeedURL</key><string>https://example.com/appcast.xml</string>" "$sandbox"
fails "SU* key" 'SUFeedURL'
app "${plist_keys/productivity/utilities}" "$sandbox"
fails "category" 'LSApplicationCategoryType'
app "${plist_keys/<true\/>/<false/>}" "$sandbox"
fails "encryption" 'ITSAppUsesNonExemptEncryption'
app "$plist_keys" "$sandbox"
rm "$tmp/Postino.app/Contents/Frameworks/cnativeapi.framework/Versions/A/Resources/PrivacyInfo.xcprivacy"
fails "framework privacy manifest" 'cnativeapi.framework'
app "$plist_keys" "$sandbox"
rm "$tmp/Postino.app/Contents/Resources/PrivacyInfo.xcprivacy"
fails "app privacy manifest" 'Contents/Resources/PrivacyInfo.xcprivacy'
app "$plist_keys" '<key>com.apple.security.network.client</key><true/>'
fails "sandbox off" 'App Sandbox'
app "$plist_keys" "$sandbox<key>com.apple.security.temporary-exception.mach-lookup.global-name</key><array><string>x-spks</string></array>"
fails "mach-lookup" 'mach-lookup'
echo "store_bundle_check.sh ok"
