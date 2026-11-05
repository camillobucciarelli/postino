#!/bin/bash
# Succeeds only when no tag release has published <object key> yet, asked to the R2 bucket's S3 API (HEAD,
# curl's SigV4; not the cached public domain). A tag run calls it before building: a tag release is final, its
# DMG/APK is cached as immutable and Sparkle's appcast signs those exact bytes, so a rerun never overwrites it.
# A manual run's upload (max-age=300, no "immutable") is still replaced by the tag run of its version.
# Any other answer (403, 5xx, a network error) fails: an unknown state never lets the release go on.
# Usage: r2_unreleased.sh <object key>   (R2_ENDPOINT overrides the account endpoint, for the self-check)
set -euo pipefail
key=${1:?usage: r2_unreleased.sh <object key>}
: "${R2_ACCESS_KEY_ID:?}" "${R2_SECRET_ACCESS_KEY:?}" "${R2_ACCOUNT_ID:?}" "${R2_BUCKET:?}"
endpoint=${R2_ENDPOINT:-https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com}

# Credentials go through stdin (--config -), not argv, as in r2_upload.sh. The empty body's sha256 is fixed.
answer=$(printf 'user = "%s:%s"\n' "$R2_ACCESS_KEY_ID" "$R2_SECRET_ACCESS_KEY" |
  curl --config - --silent --head --output /dev/null --write-out '%{http_code} %header{cache-control}' \
    --retry 3 --max-time 60 \
    --aws-sigv4 'aws:amz:auto:s3' \
    -H 'x-amz-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' \
    "$endpoint/$R2_BUCKET/$key" || true)
status=${answer%% *}
case "$status" in
  404) echo "$key is not published yet" ;;
  200)
    if [[ $answer == *immutable* ]]; then
      echo "::error::Version already published ($key): use a new tag" >&2
      exit 1
    fi
    echo "$key is a manual run's build: the tag release replaces it"
    ;;
  *)
    echo "::error::Cannot tell whether $key is published (HTTP ${status:-none}): not releasing" >&2
    exit 1
    ;;
esac
