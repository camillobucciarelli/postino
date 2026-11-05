#!/bin/bash
# Self-check of ios_export_options.sh, run by ci.yml: a valid plist for App Store Connect with the given team, and
# a refusal of anything that is not a team ID.
set -euo pipefail
cd "$(dirname "$0")/../.."
fails() { if tool/release/ios_export_options.sh "$@" > /dev/null 2>&1; then echo "passed but should fail: $*"; exit 1; fi; }

plist=$(tool/release/ios_export_options.sh A8QUU5F9G3)
get() { plutil -extract "$1" raw -o - - <<< "$plist"; }
[ "$(get method)" = app-store-connect ] || { echo "method"; exit 1; }
[ "$(get teamID)" = A8QUU5F9G3 ] || { echo "teamID"; exit 1; }
[ "$(get signingStyle)" = automatic ] || { echo "signingStyle"; exit 1; }
[ "$(get destination)" = export ] || { echo "destination"; exit 1; }
fails
fails a8quu5f9g3
fails 'A8QUU5F9G3</string>'
echo "ios_export_options.sh ok"
