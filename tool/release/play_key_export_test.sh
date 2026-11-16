#!/bin/bash
# Self-check of play_key_export.sh, run by ci.yml: the real PEPK (downloaded and hash-checked by the script) on a
# throwaway keystore and a throwaway RSA public key. Only the keystore's own certificate passes; a wrong password
# fails without hanging; the password never reaches the output; a failed run leaves no ZIP.
set -euo pipefail
script=$(cd "$(dirname "$0")" && pwd)/play_key_export.sh
tmp=$(mktemp -d "${TMPDIR:-/tmp}/pepk-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
pw=throwaway-$RANDOM-pw
keytool -genkeypair -keystore "$tmp/ks.p12" -storetype PKCS12 -alias up -keyalg RSA -keysize 2048 -validity 1 \
  -dname CN=throwaway -storepass "$pw" -keypass "$pw" > /dev/null 2>&1
cert=$(keytool -exportcert -rfc -keystore "$tmp/ks.p12" -alias up -storepass "$pw" | openssl x509 -noout -fingerprint -sha256)
cert=${cert#*=}
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 2> /dev/null | openssl pkey -pubout > "$tmp/pub.pem"
zip=$tmp/out.zip

run() { ANDROID_KEYSTORE_PASSWORD=$1 ANDROID_KEY_PASSWORD=$1 "$script" "$tmp/ks.p12" up "$2" "$zip" "${3:-$tmp/pub.pem}" > "$tmp/log" 2>&1; }
fails() { if run "$@"; then echo "should fail: $*"; exit 1; fi; test ! -e "$zip" || { echo "ZIP left behind: $*"; exit 1; }; }

run "$pw" "$cert" || { cat "$tmp/log"; echo "should pass"; exit 1; }
unzip -l "$zip" encryptedPrivateKey certificate.pem > /dev/null || { echo "ZIP misses an entry"; exit 1; }
! grep -q "$pw" "$tmp/log" || { echo "password in the output"; exit 1; }
run "$pw" "$(tr '[:upper:]' '[:lower:]' <<< "$cert")" || { echo "lowercase fingerprint should pass"; exit 1; }
fails "$pw" 47:03:4A:D7
fails wrong-password "$cert"
! grep -q wrong-password "$tmp/log" || { echo "wrong password in the output"; exit 1; }
fails "$pw" "$cert" "$tmp/ks.p12"
echo "play_key_export.sh ok"
