#!/bin/bash
# Fails unless the APK verifies with apksigner and its only signer is the expected certificate, so a
# release signed with the debug key (or any other) never reaches R2. Also fails unless versionCode and
# versionName are the expected ones (#140): Android refuses to update over a higher versionCode.
# Usage: verify_apk.sh <apk> <certificate SHA-256, AA:BB:... or hex> <versionCode> <versionName>
set -euo pipefail
apk=${1:?usage: verify_apk.sh <apk> <certificate sha256>}
expected=${2:?usage: verify_apk.sh <apk> <certificate sha256> <versionCode> <versionName>}
code=${3:?usage: verify_apk.sh <apk> <certificate sha256> <versionCode> <versionName>}
name=${4:?usage: verify_apk.sh <apk> <certificate sha256> <versionCode> <versionName>}
: "${ANDROID_HOME:?}"

apksigner=$(ls "$ANDROID_HOME"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -n 1 || true)
test -n "$apksigner" || { echo "::error::No apksigner in $ANDROID_HOME/build-tools" >&2; exit 1; }

certs=$("$apksigner" verify --print-certs "$apk")
echo "$certs"
want=$(tr -d ':' <<< "$expected" | tr 'A-F' 'a-f')
# "Signer #1 certificate ..." or "V2 Signer: certificate ..." by build-tools version; one line per scheme.
have=$(sed -n 's/^.*Signer.* certificate SHA-256 digest: //p' <<< "$certs" | sort -u)
[ "$have" = "$want" ] || { echo "::error::APK signed by $have, expected $want" >&2; exit 1; }

aapt2=$(ls "$ANDROID_HOME"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -n 1 || true)
test -n "$aapt2" || { echo "::error::No aapt2 in $ANDROID_HOME/build-tools" >&2; exit 1; }
badging=$("$aapt2" dump badging "$apk")
pkg=$(sed -n "s/^package: .*/&/p" <<< "$badging" | head -n 1)
have_code=$(sed -n "s/.* versionCode='\([^']*\)'.*/\1/p" <<< "$pkg")
have_name=$(sed -n "s/.* versionName='\([^']*\)'.*/\1/p" <<< "$pkg")
[ "$have_code" = "$code" ] || { echo "::error::APK versionCode $have_code, expected $code" >&2; exit 1; }
[ "$have_name" = "$name" ] || { echo "::error::APK versionName $have_name, expected $name" >&2; exit 1; }
