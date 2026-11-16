#!/bin/bash
# Fails unless the Google Play AAB (#345, ADR 0023) is fit for upload: a valid JAR signature (jarsigner) whose only
# signer is the upload key's certificate, so the debug key (or any other) never reaches Play; package
# com.cbucciarelli.postino; the expected versionCode and versionName (Play refuses a lower or reused versionCode);
# and no REQUEST_IGNORE_BATTERY_OPTIMIZATIONS (battery_permission_check.sh). An AAB is not an APK: apksigner does not
# read it and its manifest is protobuf, so the base module is laid out as an APK (manifest and resources.pb at the
# root), which aapt2 reads in proto format, with no bundletool.
# Usage: verify_aab.sh <aab> <certificate SHA-256, AA:BB:... or hex> <versionCode> <versionName>
set -euo pipefail
usage='usage: verify_aab.sh <aab> <certificate sha256> <versionCode> <versionName>'
aab=${1:?$usage}
expected=${2:?$usage}
code=${3:?$usage}
name=${4:?$usage}
: "${ANDROID_HOME:?}"
[ -f "$aab" ] || { echo "::error::No AAB at $aab" >&2; exit 1; }
bin=${JAVA_HOME:+$JAVA_HOME/bin/}

# jarsigner exits 0 on an unsigned file ("jar is unsigned."), and without -strict also on a signed one with entries
# added after signing. With -strict its exit code is a bit mask: 16 is an unsigned entry; 4 (a certificate chain that
# does not validate) is expected, the upload key being self-signed. Anything but 0 or 4 fails.
rc=0
verified=$("${bin}jarsigner" -verify -strict "$aab" 2>&1) || rc=$?
grep -q '^jar verified' <<< "$verified" && [ $((rc & ~4)) -eq 0 ] ||
  { echo "$verified" >&2; echo "::error::$aab: not signed, or not every entry signed (jarsigner -strict exit $rc)" >&2; exit 1; }
want=$(tr -d ':' <<< "$expected" | tr 'A-F' 'a-f')
have=$("${bin}keytool" -printcert -jarfile "$aab" | sed -n 's/^[[:space:]]*SHA256: //p' | tr -d ':' | tr 'A-F' 'a-f' | sort -u)
[ "$have" = "$want" ] || { echo "::error::AAB signed by ${have:-nobody}, expected $want" >&2; exit 1; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/aab.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
unzip -q "$aab" 'base/*' -d "$tmp"
mv "$tmp/base/manifest/AndroidManifest.xml" "$tmp/base/AndroidManifest.xml"
(cd "$tmp/base" && zip -qr ../base.apk AndroidManifest.xml resources.pb res)

aapt2=$(ls "$ANDROID_HOME"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -n 1 || true)
test -n "$aapt2" || { echo "::error::No aapt2 in $ANDROID_HOME/build-tools" >&2; exit 1; }
pkg=$("$aapt2" dump badging "$tmp/base.apk" | sed -n 's/^package: .*/&/p' | head -n 1)
have_pkg=$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" <<< "$pkg")
have_code=$(sed -n "s/.* versionCode='\([^']*\)'.*/\1/p" <<< "$pkg")
have_name=$(sed -n "s/.* versionName='\([^']*\)'.*/\1/p" <<< "$pkg")
[ "$have_pkg" = com.cbucciarelli.postino ] || { echo "::error::AAB package $have_pkg, expected com.cbucciarelli.postino" >&2; exit 1; }
[ "$have_code" = "$code" ] || { echo "::error::AAB versionCode $have_code, expected $code" >&2; exit 1; }
[ "$have_name" = "$name" ] || { echo "::error::AAB versionName $have_name, expected $name" >&2; exit 1; }
"$(dirname "$0")/battery_permission_check.sh" "$tmp/base.apk" store
echo "$aab: signed by $want, $have_pkg $have_code ($have_name)"
