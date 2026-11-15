#!/bin/bash
# Self-check of app_store_url.sh, run by ci.yml: the page only for the version the App Store offers, and a failure
# for a missing ID or a version still in review.
set -euo pipefail
cd "$(dirname "$0")/../.."
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
printf '{"resultCount":1,"results":[{"version":"1.3.0","trackId":123}]}' > "$dir/live.json"
printf '{"resultCount":0,"results":[]}' > "$dir/none.json"
run() { APP_STORE_ID=$1 APP_STORE_LOOKUP="file://$dir/$2" tool/release/app_store_url.sh "$3"; }
fails() { if run "$@" > /dev/null 2>&1; then echo "passed but should fail: $*"; exit 1; fi; }

[ "$(run 123 live.json 1.3.0)" = https://apps.apple.com/app/id123 ] || { echo "app_store_url.sh: wrong page"; exit 1; }
fails 123 live.json 1.4.0
fails 123 none.json 1.3.0
fails '' live.json 1.3.0
fails 12a live.json 1.3.0
echo "app_store_url.sh ok"
