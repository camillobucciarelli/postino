#!/bin/bash
# Self-check of testflight_upload.sh, run by ci.yml, with a fake xcrun in the PATH: the Defaults.properties error is
# retried and then succeeds (3 calls, exit 0), any other error fails at once (1 call, same exit code), and four
# Defaults.properties failures give up (4 calls). The platform reaches altool's -t: ios by default, macos for the .pkg.
set -euo pipefail
script=$(cd "$(dirname "$0")" && pwd)/testflight_upload.sh
tmp=$(mktemp -d "${TMPDIR:-/tmp}/tf-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
: > "$tmp/Postino.ipa"
cat > "$tmp/bin/xcrun" <<'FAKE'
#!/bin/bash
# FAKE_FAILS failures with FAKE_MESSAGE and exit 7, then success.
n=$(($(cat "$CALLS" 2> /dev/null || echo 0) + 1))
echo "$n" > "$CALLS"
echo "$*" > "$CALLS.args"
if [ "$n" -le "$FAKE_FAILS" ]; then echo "$FAKE_MESSAGE"; exit 7; fi
echo "upload ok"
FAKE
chmod +x "$tmp/bin/xcrun"

# run <fails> <message> <expected exit> <expected calls> [platform]
run() {
  rm -f "$tmp/calls"
  local rc=0
  PATH="$tmp/bin:$PATH" CALLS="$tmp/calls" FAKE_FAILS=$1 FAKE_MESSAGE=$2 UPLOAD_RETRY_WAIT_UNIT=0 \
    APP_STORE_CONNECT_API_KEY_BASE64=$(printf k | base64) APP_STORE_CONNECT_KEY_ID=KEYID APP_STORE_CONNECT_ISSUER_ID=ISSUER \
    "$script" "$tmp/Postino.ipa" ${5:+"$5"} > /dev/null 2>&1 || rc=$?
  [ "$rc" -eq "$3" ] && [ "$(cat "$tmp/calls")" -eq "$4" ] || { echo "fails=$1 '$2': exit $rc (want $3), calls $(cat "$tmp/calls") (want $4)"; exit 1; }
}
msg="The file “Defaults.properties” couldn’t be opened."
run 0 x 0 1
run 2 "$msg" 0 3
run 1 "Error: invalid credentials" 7 1
run 1 "Defaults-properties" 7 1
run 9 "$msg" 7 4
grep -q -- '-t ios ' "$tmp/calls.args" || { echo "default platform: $(cat "$tmp/calls.args")"; exit 1; }
run 0 x 0 1 macos
grep -q -- '-t macos ' "$tmp/calls.args" || { echo "macos platform: $(cat "$tmp/calls.args")"; exit 1; }
rm -f "$tmp/calls"
out=$(PATH="$tmp/bin:$PATH" CALLS="$tmp/calls" FAKE_FAILS=0 FAKE_MESSAGE=x APP_STORE_CONNECT_API_KEY_BASE64=$(printf k | base64) \
  APP_STORE_CONNECT_KEY_ID=KEYID APP_STORE_CONNECT_ISSUER_ID=ISSUER "$script" "$tmp/Postino.ipa" tvos 2>&1) &&
  { echo "an unknown platform should fail"; exit 1; }
grep -qF 'Not ios or macos: tvos' <<< "$out" && [ ! -e "$tmp/calls" ] || { echo "unknown platform: $out"; exit 1; }
echo "testflight_upload.sh ok"
