#!/bin/bash
# Uploads a file to the Cloudflare R2 bucket via its S3 API (curl's SigV4, no aws CLI). An existing
# object at the same key is replaced: the tag run of a version supersedes a manual run of it (release.yml
# refuses manual runs of a version that already has its tag).
# Usage: r2_upload.sh <file> <object key> <content type>
set -euo pipefail
file=${1:?usage: r2_upload.sh <file> <key> <content type>}
key=${2:?usage: r2_upload.sh <file> <key> <content type>}
type=${3:?usage: r2_upload.sh <file> <key> <content type>}
: "${R2_ACCESS_KEY_ID:?}" "${R2_SECRET_ACCESS_KEY:?}" "${R2_ACCOUNT_ID:?}" "${R2_BUCKET:?}"

sha=$(shasum -a 256 "$file" | cut -d ' ' -f 1)
# Credentials go through stdin (--config -), not argv, so they never show in the process list.
printf 'user = "%s:%s"\n' "$R2_ACCESS_KEY_ID" "$R2_SECRET_ACCESS_KEY" |
  curl --config - --fail-with-body --silent --show-error \
    --retry 3 --max-time 1800 \
    --aws-sigv4 'aws:amz:auto:s3' \
    -H "x-amz-content-sha256: $sha" \
    -H "Content-Type: $type" \
    --upload-file "$file" \
    "https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com/$R2_BUCKET/$key"
echo "Uploaded $key ($sha)"
