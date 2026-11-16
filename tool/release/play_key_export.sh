#!/bin/bash
# Exports the upload key for Play App Signing (#345, ADR 0023): Google's PEPK tool encrypts the private key with
# Play's public key into a ZIP that only Google can read, with the certificate, which must be the one that signs the
# site's APK. Run once by play-key-export.yml; the ZIP goes to Play Console, «Change key → Export and upload a key
# from Java keystore».
# Usage: play_key_export.sh <keystore> <alias> <expected cert SHA-256> <output.zip> [encryption public key PEM]
# Passwords come from ANDROID_KEYSTORE_PASSWORD and ANDROID_KEY_PASSWORD. PEPK reads them only from argv
# (--keystore-pass, --key-pass, which `ps` shows and which PEPK prints whole on a flag error) or from the console,
# so expect types them at its prompts on a pseudo-terminal: Java turns echo off before prompting.
set -euo pipefail
: "${ANDROID_KEYSTORE_PASSWORD:?}" "${ANDROID_KEY_PASSWORD:?}"
usage="usage: play_key_export.sh <keystore> <alias> <cert SHA-256> <output.zip> [public key PEM]"
keystore=${1:?$usage} alias=${2:?$usage} want=${3:?$usage} out=${4:?$usage}
encryption_key=${5:-$(cd "$(dirname "$0")" && pwd)/play_encryption_public_key.pem}

# The jar the Play Console links to (sources: pepk-src.jar, same folder). Unsigned: the hash is the only check. The URL
# carries no version: a mismatch means Google republished it, so vet the new jar and its sources before re-pinning.
pepk_url=https://www.gstatic.com/play-apps-publisher-rapid/signing-tool/prod/pepk.jar
pepk_sha256=aaccc0774b240aa5304bdad2a49865e92f229ca73209ecb6eaafe75dc858e24e

tmp=$(mktemp -d "${TMPDIR:-/tmp}/pepk.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
curl -fsS --proto '=https' --retry 3 --max-time 120 -o "$tmp/pepk.jar" "$pepk_url"
echo "$pepk_sha256  $tmp/pepk.jar" | shasum -a 256 -c --status \
  || { echo "::error::pepk.jar does not match the pinned SHA-256" >&2; exit 1; }
openssl pkey -pubin -in "$encryption_key" -noout \
  || { echo "::error::$encryption_key is not a public key" >&2; exit 1; }

# A failed run must not leave a ZIP behind (PEPK also refuses an existing output).
rm -f "$out"
fail() { rm -f "$out"; echo "::error::$1" >&2; exit 1; }
cat > "$tmp/pepk.exp" <<'EXP'
set timeout 120
spawn -noecho java -jar {*}$argv
expect {
  "Enter password for store" { send -- "$env(ANDROID_KEYSTORE_PASSWORD)\r"; exp_continue }
  "Enter password for key" { send -- "$env(ANDROID_KEY_PASSWORD)\r"; exp_continue }
  timeout { exit 124 }
  eof
}
exit [lindex [wait] 3]
EXP
expect -f "$tmp/pepk.exp" "$tmp/pepk.jar" --keystore="$keystore" --alias="$alias" --output="$out" --include-cert \
  --rsa-aes-encryption --encryption-key-path="$encryption_key" || fail "PEPK failed"

unzip -l "$out" encryptedPrivateKey > /dev/null || fail "no encryptedPrivateKey in $out"
have=$(unzip -p "$out" certificate.pem | openssl x509 -noout -fingerprint -sha256) || fail "no certificate.pem in $out"
have=$(tr '[:lower:]' '[:upper:]' <<< "${have#*=}")
[ "$have" = "$(tr '[:lower:]' '[:upper:]' <<< "$want")" ] || fail "certificate SHA-256 $have, expected $want"
echo "PEPK export ok: certificate SHA-256 $have"
