#!/bin/bash
# Fails unless the APK verifies with apksigner and its only signer is the expected certificate, so a
# release signed with the debug key (or any other) never reaches R2.
# Usage: verify_apk.sh <apk> <certificate SHA-256, AA:BB:... or hex>
set -euo pipefail
apk=${1:?usage: verify_apk.sh <apk> <certificate sha256>}
expected=${2:?usage: verify_apk.sh <apk> <certificate sha256>}
: "${ANDROID_HOME:?}"

apksigner=$(ls "$ANDROID_HOME"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -n 1)
test -n "$apksigner" || { echo "::error::No apksigner in $ANDROID_HOME/build-tools" >&2; exit 1; }

certs=$("$apksigner" verify --print-certs "$apk")
echo "$certs"
want=$(tr -d ':' <<< "$expected" | tr 'A-F' 'a-f')
# "Signer #1 certificate ..." or "V2 Signer: certificate ..." by build-tools version; one line per scheme.
have=$(sed -n 's/^.*Signer.* certificate SHA-256 digest: //p' <<< "$certs" | sort -u)
[ "$have" = "$want" ] || { echo "::error::APK signed by $have, expected $want" >&2; exit 1; }
