#!/bin/bash
# Prints the App Store page of Postino (#323), https://apps.apple.com/app/id<APP_STORE_ID>, only once <X.Y.Z> is the
# version the App Store offers (iTunes Search API, Italian storefront): the iOS version file must not announce a
# version that is still in review. Fails otherwise, and when APP_STORE_ID (the numeric Apple ID of App Store Connect,
# App information) is missing or not a number. APP_STORE_LOOKUP overrides the lookup URL, for the self-check.
# Usage: app_store_url.sh <X.Y.Z>
set -euo pipefail
version=${1:?usage: app_store_url.sh <X.Y.Z>}
if ! [[ ${APP_STORE_ID:-} =~ ^[0-9]+$ ]]; then
  echo "::error::APP_STORE_ID is not a numeric Apple ID: set the repository variable" >&2
  exit 1
fi

lookup=${APP_STORE_LOOKUP:-https://itunes.apple.com/lookup?id=$APP_STORE_ID&country=it}
body=$(curl -fsS --max-time 30 "$lookup")
live=$(plutil -extract results.0.version raw -o - - <<< "$body" 2>/dev/null || true)
if [ "$live" != "$version" ]; then
  echo "::error::The App Store offers ${live:-nothing}, not $version: release it in App Store Connect first" >&2
  exit 1
fi
echo "https://apps.apple.com/app/id$APP_STORE_ID"
