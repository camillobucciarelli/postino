#!/bin/bash
# Self-check of play_upload.sh, run by ci.yml, with a fake curl in the PATH and a throwaway RSA key: the JWT has the
# service account as issuer, the androidpublisher scope, Google's token audience and a signature that verifies with the
# key; the requests are insert, upload, track update, commit, in that order, with the token from a header file; a draft
# app gets the release again as a draft; a wrong versionCode or any other refusal fails and drops the edit.
set -euo pipefail
script=$(cd "$(dirname "$0")" && pwd)/play_upload.sh
tmp=$(mktemp -d "${TMPDIR:-/tmp}/play-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
: > "$tmp/app.aab"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$tmp/key.pem" 2> /dev/null
openssl pkey -in "$tmp/key.pem" -pubout -out "$tmp/pub.pem"
account=$(jq -n --rawfile key "$tmp/key.pem" '{type: "service_account", client_email: "ci@p.iam.gserviceaccount.com", private_key: $key}' | base64)

cat > "$tmp/bin/curl" <<'FAKE'
#!/bin/bash
# Logs "<method> <url>" (and the JWT, the track body), answers as Google would; FAKE_DRAFT refuses a completed release
# as on a draft app, FAKE_CODE is the versionCode Play reads, FAKE_FAIL fails that request.
method=GET url='' assertion='' body=''
while [ $# -gt 0 ]; do
  case "$1" in
    -X) method=$2; shift ;;
    -H) [[ $2 == @* ]] && cp "${2#@}" "$LOG.auth"; shift ;;
    --data-urlencode) [[ $2 == assertion=* ]] && assertion=${2#assertion=}; method=POST; shift ;;
    --data-binary) [ "$2" = @- ] && body=$(cat); shift ;;
    http*) url=$1 ;;
  esac
  shift
done
echo "$method ${url#http://play}" >> "$LOG"
[ -n "$assertion" ] && echo "$assertion" > "$LOG.jwt"
[ -n "$body" ] && echo "$body" >> "$LOG.body"
[ "${FAKE_FAIL:-}" = "$method ${url#http://play}" ] && { echo '{"error":{"message":"boom"}}'; exit 22; }
case "$url" in
  */token) echo '{"access_token":"tok","expires_in":3599}' ;;
  */bundles*) echo "{\"versionCode\":${FAKE_CODE:-1002003}}" ;;
  */tracks/*) if [ -n "${FAKE_DRAFT:-}" ] && [[ $body == *'"completed"'* ]]; then
      echo '{"error":{"code":400,"message":"Only releases with status draft may be created on draft app."}}'; exit 22
    fi; echo '{}' ;;
  *:commit | */edits/e1) echo '{}' ;;
  */edits) echo '{"id":"e1"}' ;;
esac
FAKE
chmod +x "$tmp/bin/curl"

e=/androidpublisher/v3/applications/com.cbucciarelli.postino/edits
upload="POST /upload/androidpublisher/v3/applications/com.cbucciarelli.postino/edits/e1/bundles?uploadType=media"
# run 0|fail [VAR=value...]
run() {
  local want=$1 rc=0
  shift
  rm -f "$tmp/log"*
  env PATH="$tmp/bin:$PATH" LOG="$tmp/log" PLAY_SERVICE_ACCOUNT_JSON_BASE64="$account" PLAY_API_URL=http://play \
    PLAY_TOKEN_URL=http://play/token "$@" "$script" "$tmp/app.aab" 1002003 1.2.3 > "$tmp/out" 2>&1 || rc=$?
  { [ "$want" = 0 ] && [ "$rc" -eq 0 ]; } || { [ "$want" = fail ] && [ "$rc" -ne 0 ]; } || { echo "exit $rc, want $want ($*):"; cat "$tmp/out"; exit 1; }
}
calls() { [ "$(cat "$tmp/log")" = "$(printf '%s\n' "$@")" ] || { echo "calls:"; cat "$tmp/log"; echo "want:"; printf '%s\n' "$@"; exit 1; }; }

run 0
calls "POST /token" "POST $e" "$upload" "PUT $e/e1/tracks/internal" "POST $e/e1:commit"
grep -qx 'Authorization: Bearer tok' "$tmp/log.auth" || { echo "no bearer header"; exit 1; }
grep -q '::add-mask::tok' "$tmp/out" || { echo "token not masked"; exit 1; }
jq -e '.track == "internal" and .releases == [{name: "1.2.3", versionCodes: ["1002003"], status: "completed"}]' \
  "$tmp/log.body" > /dev/null || { echo "track body: $(cat "$tmp/log.body")"; exit 1; }
# The JWT: header, claims, RS256 signature over "<header>.<claims>".
unb64url() { local s; s=$(tr '_-' '/+' <<< "$1"); while [ $((${#s} % 4)) -ne 0 ]; do s="$s="; done; base64 -D <<< "$s"; }
IFS=. read -r h c s < "$tmp/log.jwt"
[ "$(unb64url "$h")" = '{"alg":"RS256","typ":"JWT"}' ] || { echo "header: $(unb64url "$h")"; exit 1; }
unb64url "$c" | jq -e '.iss == "ci@p.iam.gserviceaccount.com" and .scope == "https://www.googleapis.com/auth/androidpublisher"
  and .aud == "https://oauth2.googleapis.com/token" and .exp - .iat == 600 and (.iat - now | fabs) < 60' > /dev/null ||
  { echo "claims: $(unb64url "$c")"; exit 1; }
unb64url "$s" > "$tmp/sig"
printf '%s' "$h.$c" | openssl dgst -sha256 -verify "$tmp/pub.pem" -signature "$tmp/sig" > /dev/null ||
  { echo "JWT signature does not verify"; exit 1; }

run 0 FAKE_DRAFT=1
calls "POST /token" "POST $e" "$upload" "PUT $e/e1/tracks/internal" "PUT $e/e1/tracks/internal" "POST $e/e1:commit"
[ "$(jq -r '.releases[0].status' "$tmp/log.body" | tr '\n' ' ')" = 'completed draft ' ] || { echo "draft retry: $(cat "$tmp/log.body")"; exit 1; }
grep -q 'status draft' "$tmp/out" || { echo "draft not reported"; exit 1; }

run fail FAKE_CODE=7
calls "POST /token" "POST $e" "$upload" "DELETE $e/e1"
run fail FAKE_FAIL="PUT $e/e1/tracks/internal"
calls "POST /token" "POST $e" "$upload" "PUT $e/e1/tracks/internal" "DELETE $e/e1"
grep -q 'boom' "$tmp/out" || { echo "Google's message not shown"; exit 1; }
run fail FAKE_FAIL="POST $e/e1:commit"
calls "POST /token" "POST $e" "$upload" "PUT $e/e1/tracks/internal" "POST $e/e1:commit" "DELETE $e/e1"
run fail FAKE_FAIL="POST /token"
calls "POST /token"
run fail PLAY_SERVICE_ACCOUNT_JSON_BASE64="$(printf '{}' | base64)"
[ ! -e "$tmp/log" ] || { echo "a malformed key reached curl"; exit 1; }
grep -q 'not a service account JSON key' "$tmp/out" || { cat "$tmp/out"; exit 1; }
echo "play_upload.sh ok"
