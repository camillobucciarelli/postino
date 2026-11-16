#!/bin/bash
# Self-check of verify_aab.sh, run by ci.yml: stub jarsigner and keytool (JAVA_HOME) and a stub aapt2 print canned
# output for a minimal AAB; only a verified JAR signed by the expected single signer, with the expected package,
# versionCode and versionName and without REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, passes. The aapt2 stub also checks
# that it gets the base module laid out as an APK.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/build-tools/99.0.0" "$tmp/java/bin" "$tmp/aab/base/manifest" "$tmp/aab/base/res"
: > "$tmp/aab/base/manifest/AndroidManifest.xml"
: > "$tmp/aab/base/resources.pb"
: > "$tmp/aab/base/res/x"
(cd "$tmp/aab" && zip -qr ../app.aab base)
want=AA:BB:CC

stub() { printf '#!/bin/bash\n%s\n' "$2" > "$1"; chmod +x "$1"; }
# jar_prints <first line> [exit code]: as jarsigner -verify -strict (a run without -strict fails).
jar_prints() { stub "$tmp/java/bin/jarsigner" "[[ \" \$* \" == *' -strict '* ]] || exit 99; printf '%s\n' '$1'; exit ${2:-0}"; }
certs() { stub "$tmp/java/bin/keytool" "printf '%s\n' $(printf "'Signer #1:' '  SHA256: %s' " "$@")"; }
badging() {
  stub "$tmp/build-tools/99.0.0/aapt2" "unzip -l \"\$3\" | grep -q ' AndroidManifest.xml\$' && unzip -l \"\$3\" | grep -q ' resources.pb\$' || exit 3
case \$2 in
  badging) echo \"package: name='$1' versionCode='$2' versionName='$3' platformBuildVersionName='16'\" ;;
  permissions) printf '%s\n' 'package: $1' \"uses-permission: name='android.permission.INTERNET'\" ${4:-} ;;
esac"
}
run() { ANDROID_HOME="$tmp" JAVA_HOME="$tmp/java" tool/release/verify_aab.sh "$tmp/app.aab" "$want" 1002003 1.2.3 > "$tmp/out" 2>&1; }
passes() { run || { echo "should pass: $1"; cat "$tmp/out"; exit 1; }; }
fails() { if run; then echo "should fail: $1"; exit 1; fi; }

jar_prints 'jar verified.'
certs AA:BB:CC
badging com.cbucciarelli.postino 1002003 1.2.3
passes "upload key, expected manifest"
certs aa:bb:cc AA:BB:CC
passes "the same signer, twice"
certs DD:EE:FF
fails "other signer"
certs AA:BB:CC DD:EE:FF
fails "second signer"
stub "$tmp/java/bin/keytool" "echo 'Not a signed jar file'"
fails "no signer"
certs AA:BB:CC
jar_prints 'jar verified, with signer errors.' 4
passes "self-signed upload key (exit 4, as the real AAB)"
jar_prints 'jar is unsigned.'
fails "unsigned"; grep -q "not signed" "$tmp/out" || { cat "$tmp/out"; exit 1; }
jar_prints 'jar verified, with signer errors.' 20
fails "an entry added after signing (exit 16 + 4)"
jar_prints 'jar verified.' 1
fails "jarsigner fails"
jar_prints 'jar verified.'
badging com.cbucciarelli.postino 1 1.2.3
fails "versionCode 1"
badging com.cbucciarelli.postino 1002003 1.2.4
fails "other versionName"
badging com.example 1002003 1.2.3
fails "other package"; grep -q "package com.example" "$tmp/out" || { cat "$tmp/out"; exit 1; }
badging com.cbucciarelli.postino 1002003 1.2.3 "\"uses-permission: name='android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'\""
fails "battery permission declared"; grep -q REQUEST_IGNORE "$tmp/out" || { cat "$tmp/out"; exit 1; }
stub "$tmp/build-tools/99.0.0/aapt2" "exit 1"
fails "aapt2 fails"
rm "$tmp/build-tools/99.0.0/aapt2"
fails "no aapt2"
grep -q 'No aapt2' "$tmp/out" || { echo "missing aapt2: no error"; exit 1; }
echo "verify_aab.sh ok"
