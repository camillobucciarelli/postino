#!/bin/bash
# Self-check of appcast.sh, run by ci.yml: with a throwaway key pair and a fake app in a DMG it writes a signed
# appcast pointing at the versioned DMG, and Sparkle's sign_update refuses that appcast once tampered with.
# A key that does not match the app's SUPublicEDKey, or no key at all, stops it.
# Resolves the Sparkle package (Sparkle's own tools) unless SPARKLE_BIN points at them.
set -euo pipefail
cd "$(dirname "$0")/../.."
fails() { if "$@" > /dev/null 2>&1; then echo "passed but should fail: $*"; exit 1; fi; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
if [ -z "${SPARKLE_BIN:-}" ]; then
  xcodebuild -resolvePackageDependencies -project macos/Runner.xcodeproj -scheme Runner \
    -clonedSourcePackagesDirPath "$work/packages" > /dev/null
  export SPARKLE_BIN="$work/packages/artifacts/sparkle/Sparkle/bin"
fi

# Two throwaway Ed25519 pairs, "private public" each, in Sparkle's format (base64 of the raw 32 bytes).
pair() {
  swift - <<'EOF'
import CryptoKit
let key = Curve25519.Signing.PrivateKey()
print(key.rawRepresentation.base64EncodedString(), key.publicKey.rawRepresentation.base64EncodedString())
EOF
}
read -r private public <<< "$(pair)"
read -r other _ <<< "$(pair)"

app="$work/dmg/Postino.app"
mkdir -p "$app/Contents/MacOS"
cp /usr/bin/true "$app/Contents/MacOS/Postino"
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Postino</string>
  <key>CFBundleIdentifier</key><string>com.cbucciarelli.postino.appcast-test</string>
  <key>CFBundleName</key><string>Postino</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.2.3</string>
  <key>CFBundleVersion</key><string>$(tool/release/build_number.sh 1.2.3)</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>SUPublicEDKey</key><string>$public</string>
  <key>SURequireSignedFeed</key><true/>
  <key>SUVerifyUpdateBeforeExtraction</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$app"
dmg="$work/Postino-1.2.3.dmg"
hdiutil create -quiet -fs HFS+ -volname Postino -srcfolder "$work/dmg" "$dmg"
prefix=https://example.test/macos/1.2.3/

SPARKLE_ED_PRIVATE_KEY=$private tool/release/appcast.sh "$dmg" "$prefix" "$work/appcast.xml" > /dev/null
grep -q "url=\"${prefix}Postino-1.2.3.dmg\"" "$work/appcast.xml" || { echo "enclosure is not the versioned DMG"; exit 1; }
grep -q '<sparkle:version>1002003</sparkle:version>' "$work/appcast.xml" || { echo "sparkle:version is not the build number"; exit 1; }
grep -q '<sparkle:shortVersionString>1.2.3</sparkle:shortVersionString>' "$work/appcast.xml" ||
  { echo "sparkle:shortVersionString is not X.Y.Z"; exit 1; }

# The same feed pointing elsewhere, same length (else only the signed length catches it): the signature fails.
sed 's|example.test|exampla.test|' "$work/appcast.xml" > "$work/tampered.xml"
fails sh -c 'printf %s "$1" | "$SPARKLE_BIN/sign_update" --verify --ed-key-file - "$2"' _ "$private" "$work/tampered.xml"

fails env SPARKLE_ED_PRIVATE_KEY="$other" tool/release/appcast.sh "$dmg" "$prefix" "$work/other.xml"
fails env SPARKLE_ED_PRIVATE_KEY= tool/release/appcast.sh "$dmg" "$prefix" "$work/none.xml"
echo "appcast.sh ok"
