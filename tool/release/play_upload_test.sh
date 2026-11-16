#!/bin/bash
# Self-check of play_upload.sh, run by ci.yml, with a fake curl in the PATH and a throwaway RSA key: the JWT has the
# service account as issuer, the androidpublisher scope, Google's token audience and a signature that verifies with the
# key; the requests are insert, upload, track update, commit, in that order, with the token from a header file; a draft
# app (refused at the track update or at the commit) gets the whole edit again as a draft; a wrong versionCode or any
# other refusal fails and drops the edit. Like Google's front end, the fake refuses a POST with no Content-Length.
set -euo pipefail
script=$(cd "$(dirname "$0")" && pwd)/play_upload.sh
tmp=$(mktemp -d "${TMPDIR:-/tmp}/play-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
printf 'PK aab bytes' > "$tmp/app.aab"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$tmp/key.pem" 2> /dev/null
openssl pkey -in "$tmp/key.pem" -pubout -out "$tmp/pub.pem"
account=$(jq -n --rawfile key "$tmp/key.pem" '{type: "service_account", client_email: "ci@p.iam.gserviceaccount.com", private_key: $key}' | base64)

cat > "$tmp/bin/curl" <<'FAKE'
#!/bin/bash
# Logs "<method> <url>" (and the JWT, the track body, the uploaded file), answers as Google would; FAKE_DRAFT=track or
# commit refuses a completed release there, as on a draft app; FAKE_CODE is the versionCode Play reads; FAKE_FAIL fails
# that request.
echo "$*" >> "$LOG.argv"
method=GET url='' assertion='' body='' length=''
while [ $# -gt 0 ]; do
  case "$1" in
    -X) method=$2; shift ;;
    -H) [[ $2 == @* ]] && cp "${2#@}" "$LOG.auth"; [[ $2 == Content-Length:* ]] && length=y; shift ;;
    --data-urlencode) [[ $2 == assertion@* ]] && assertion=$(cat "${2#assertion@}"); method=POST length=y; shift ;;
    --data-binary) if [ "$2" = @- ]; then body=$(cat); else cp "${2#@}" "$LOG.uploaded"; fi; length=y; shift ;;
    http*) url=$1 ;;
  esac
  shift
done
echo "$method ${url#http://play}" >> "$LOG"
[ -n "$assertion" ] && echo "$assertion" > "$LOG.jwt"
[ -n "$body" ] && echo "$body" >> "$LOG.body"
[ "${FAKE_FAIL:-}" = "$method ${url#http://play}" ] && { echo '{"error":{"message":"boom"}}'; exit 22; }
[ "$method" = POST ] && [ -z "$length" ] && { echo '411. POST requests require a Content-length header.'; exit 22; }
draft() { echo '{"error":{"code":400,"message":"Only releases with status draft may be created on draft app."}}'; exit 22; }
case "$url" in
  */token) echo '{"access_token":"ya29.secret-token","expires_in":3599}' ;;
  */bundles*) echo "{\"versionCode\":${FAKE_CODE:-1002003}}" ;;
  */tracks/*) [ "${FAKE_DRAFT:-}" = track ] && [[ $body == *'"completed"'* ]] && draft; echo '{}' ;;
  *:commit) [ "${FAKE_DRAFT:-}" = commit ] && [[ $(tail -n 1 "$LOG.body") == *'"completed"'* ]] && draft; echo '{}' ;;
  */edits/e1) echo '{}' ;;
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
grep -qx 'Authorization: Bearer ya29.secret-token' "$tmp/log.auth" || { echo "no bearer header"; exit 1; }
cmp -s "$tmp/app.aab" "$tmp/log.uploaded" || { echo "the upload did not send the AAB"; exit 1; }
grep -q '::add-mask::ya29.secret-token' "$tmp/out" || { echo "token not masked"; exit 1; }
jq -e '.track == "internal" and .releases == [{name: "1.2.3", versionCodes: ["1002003"], status: "completed"}]' \
  "$tmp/log.body" > /dev/null || { echo "track body: $(cat "$tmp/log.body")"; exit 1; }
# No secret on a command line: neither the token nor the JWT (nor the key) in curl's arguments.
! grep -qe ya29.secret-token -e "$(cut -c1-40 "$tmp/log.jwt")" -e PRIVATE "$tmp/log.argv" || { echo "secret in curl argv:"; cat "$tmp/log.argv"; exit 1; }
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

drafts() {
  [ "$(jq -r '.releases[0].status' "$tmp/log.body" | tr '\n' ' ')" = 'completed draft ' ] || { echo "draft retry: $(cat "$tmp/log.body")"; exit 1; }
  grep -q 'status draft' "$tmp/out" || { echo "draft not reported"; exit 1; }
}
run 0 FAKE_DRAFT=track
calls "POST /token" "POST $e" "$upload" "PUT $e/e1/tracks/internal" "DELETE $e/e1" \
  "POST $e" "$upload" "PUT $e/e1/tracks/internal" "POST $e/e1:commit"
drafts
run 0 FAKE_DRAFT=commit
calls "POST /token" "POST $e" "$upload" "PUT $e/e1/tracks/internal" "POST $e/e1:commit" "DELETE $e/e1" \
  "POST $e" "$upload" "PUT $e/e1/tracks/internal" "POST $e/e1:commit"
drafts

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
run fail PLAY_SERVICE_ACCOUNT_JSON_BASE64='not base64!'
[ ! -e "$tmp/log" ] && grep -q 'not a service account JSON key' "$tmp/out" || { echo "bad base64:"; cat "$tmp/out"; exit 1; }
echo "play_upload.sh ok"
