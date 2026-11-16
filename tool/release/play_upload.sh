#!/bin/bash
# Uploads the Google Play AAB (#345, ADR 0023) to the internal testing track with the Google Play Developer API, as
# the service account of PLAY_SERVICE_ACCOUNT_JSON_BASE64 (its JSON key, base64). curl, openssl and jq only:
# - access token: a JWT signed RS256 with the key, exchanged at https://oauth2.googleapis.com/token, scope
#   androidpublisher (https://developers.google.com/identity/protocols/oauth2/service-account);
# - one edit: edits.insert -> edits.bundles.upload (uploadType=media, application/octet-stream) -> edits.tracks.update
#   (PUT, track internal) -> edits.commit (https://developers.google.com/android-publisher/edits and api-ref/rest/v3).
# The API changes only an app that already has an upload from the Play Console ("You can only use this API to make
# changes to an existing app (that has at least one APK uploaded)", edits page): the first AAB goes in by hand, from
# the workflow's artifact. Release status `completed`; while the app is still a draft in the Console Play accepts only
# `draft` releases ("Only releases with status draft may be created on draft app"), so on that refusal the release is
# made again as a draft, to be rolled out by hand from the Console. Play refuses a versionCode it already has, so a
# rerun of an uploaded version fails at the upload: that is the only duplicate guard, as on TestFlight.
# PLAY_API_URL and PLAY_TOKEN_URL override Google's endpoints, for the self-check only.
# Usage: play_upload.sh <aab> <versionCode> <versionName>
set -euo pipefail
usage='usage: play_upload.sh <aab> <versionCode> <versionName>'
aab=${1:?$usage}
code=${2:?$usage}
name=${3:?$usage}
: "${PLAY_SERVICE_ACCOUNT_JSON_BASE64:?}"
[ -f "$aab" ] || { echo "::error::Nothing to upload at $aab" >&2; exit 1; }
package=com.cbucciarelli.postino
track=internal
api=${PLAY_API_URL:-https://androidpublisher.googleapis.com}
token_url=${PLAY_TOKEN_URL:-https://oauth2.googleapis.com/token}

dir=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/play.XXXXXX")
# A cancelled job gets SIGTERM, which skips an EXIT-only trap: the decoded key and the token must not outlive the run.
trap 'rm -rf "$dir"' EXIT
trap 'exit 1' HUP INT TERM
umask 077
printf '%s' "$PLAY_SERVICE_ACCOUNT_JSON_BASE64" | base64 -D > "$dir/account.json"
email=$(jq -er .client_email "$dir/account.json") && jq -er .private_key "$dir/account.json" > "$dir/key.pem" ||
  { echo "::error::PLAY_SERVICE_ACCOUNT_JSON_BASE64 is not a service account JSON key" >&2; exit 1; }

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
now=$(date +%s)
claims=$(jq -cn --arg iss "$email" --argjson iat "$now" \
  '{iss: $iss, scope: "https://www.googleapis.com/auth/androidpublisher", aud: "https://oauth2.googleapis.com/token",
    iat: $iat, exp: ($iat + 600)}')
unsigned="$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | b64url).$(printf '%s' "$claims" | b64url)"
signature=$(printf '%s' "$unsigned" | openssl dgst -sha256 -sign "$dir/key.pem" -binary | b64url)

# request <curl args...>: the response body on stdout; on an HTTP error Google's message on stderr and exit 1.
request() {
  local rc=0
  curl -sS --fail-with-body "$@" > "$dir/response" || rc=$?
  [ "$rc" -eq 0 ] || { echo "::error::Google Play API request failed (curl $rc): $(cat "$dir/response")" >&2; return 1; }
  cat "$dir/response"
}
# The signed JWT, the token and the key reach curl and openssl from files in $dir (mode 0600), never on a command
# line, where `ps` on the shared runner would show them.
printf '%s.%s' "$unsigned" "$signature" > "$dir/jwt"
token=$(request --data-urlencode grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer \
  --data-urlencode assertion@"$dir/jwt" "$token_url" | jq -er .access_token)
echo "::add-mask::$token"
printf 'Authorization: Bearer %s\n' "$token" > "$dir/auth"
play() { request -H @"$dir/auth" "$@"; }

base="$api/androidpublisher/v3/applications/$package/edits"
edit=$(play -X POST "$base" | jq -er .id)
# An edit that does not reach the commit is dropped, so the next run does not find it open.
trap 'play -X DELETE "$base/$edit" > /dev/null 2>&1 || true; rm -rf "$dir"' EXIT

uploaded=$(play -X POST -H 'Content-Type: application/octet-stream' --data-binary @"$aab" \
  "$api/upload/androidpublisher/v3/applications/$package/edits/$edit/bundles?uploadType=media" | jq -er .versionCode)
[ "$uploaded" = "$code" ] || { echo "::error::Play read versionCode $uploaded, expected $code" >&2; exit 1; }

release() {
  jq -cn --arg name "$name" --arg code "$code" --arg status "$1" --arg track "$track" \
    '{track: $track, releases: [{name: $name, versionCodes: [$code], status: $status}]}' |
    play -X PUT -H 'Content-Type: application/json' --data-binary @- "$base/$edit/tracks/$track" > /dev/null
}
status=completed
if ! release completed 2> "$dir/release.err"; then
  grep -Fq 'Only releases with status draft may be created on draft app' "$dir/release.err" || { cat "$dir/release.err" >&2; exit 1; }
  echo "::warning::The app is still a draft in the Play Console: release $name saved as a draft, roll it out by hand"
  status=draft
  release draft
fi
play -X POST "$base/$edit:commit" > /dev/null
trap 'rm -rf "$dir"' EXIT
echo "versionCode $code ($name) on the $track track, status $status"
