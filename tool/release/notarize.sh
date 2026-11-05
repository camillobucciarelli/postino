#!/bin/bash
# Notarizes an .app (zipped for upload) or a .dmg with the App Store Connect API key, waits for the
# verdict, prints Apple's log on rejection, then staples the ticket to the given path.
# Usage: notarize.sh <app|dmg>
set -euo pipefail
target=${1:?usage: notarize.sh <app|dmg>}
: "${APP_STORE_CONNECT_API_KEY_BASE64:?}" "${APP_STORE_CONNECT_KEY_ID:?}" "${APP_STORE_CONNECT_ISSUER_ID:?}"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
key="$work/AuthKey.p8"
(umask 077 && printf '%s' "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 -D > "$key")
auth=(--key "$key" --key-id "$APP_STORE_CONNECT_KEY_ID" --issuer "$APP_STORE_CONNECT_ISSUER_ID")

upload=$target
if [[ $target == *.app ]]; then
  upload="$work/$(basename "$target").zip"
  ditto -c -k --keepParent "$target" "$upload"
fi

result=$(xcrun notarytool submit "$upload" "${auth[@]}" --wait --output-format json)
status=$(plutil -extract status raw -o - - <<< "$result")
if [ "$status" != Accepted ]; then
  echo "::error::Notarization of $(basename "$target"): $status" >&2
  xcrun notarytool log "$(plutil -extract id raw -o - - <<< "$result")" "${auth[@]}" >&2 || true
  exit 1
fi
xcrun stapler staple "$target"
