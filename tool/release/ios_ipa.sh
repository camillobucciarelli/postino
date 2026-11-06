#!/bin/bash
# Archives the Runner (unsigned) and exports the App Store IPA, signed by Xcode with the App Store Connect API key:
# -allowProvisioningUpdates lets it create the cloud-managed distribution certificate and App Store profile, so no
# certificate or profile secret exists and the keychain needs nothing. The archive is unsigned on purpose: a
# development signature would need a registered device in the team, a distribution one is made at export.
# Run after `flutter build ios --config-only --release --build-number=N --dart-define=...`, which writes the
# version, build number and dart-defines into ios/Flutter/Generated.xcconfig that the archive reads.
# Usage: ios_ipa.sh <out-dir>   -> <out-dir>/Postino.ipa
set -euo pipefail
out=${1:?usage: ios_ipa.sh <out-dir>}
: "${APPLE_TEAM_ID:?}" "${APP_STORE_CONNECT_API_KEY_BASE64:?}" "${APP_STORE_CONNECT_KEY_ID:?}" "${APP_STORE_CONNECT_ISSUER_ID:?}"
cd "$(dirname "$0")/../.."

work=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ios-ipa.XXXXXX")
# A cancelled job gets SIGTERM, which skips an EXIT-only trap: the decoded key must not outlive the run.
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM
key="$work/AuthKey.p8"
(umask 077 && printf '%s' "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 -D > "$key")
auth=(-allowProvisioningUpdates -authenticationKeyPath "$key" -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID"
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID")

mkdir -p "$out"
archive="$work/Runner.xcarchive"
# The project's DEVELOPMENT_TEAM is the author's personal one: the real team is forced here.
xcodebuild archive -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -archivePath "$archive" \
  CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM="$APPLE_TEAM_ID" | tail -n 40
tool/release/ios_export_options.sh "$APPLE_TEAM_ID" > "$work/ExportOptions.plist"
if ! xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$work/ExportOptions.plist" \
  -exportPath "$work/export" "${auth[@]}"; then
  echo "::error::IPA export failed: if Xcode could not create the certificate or profile, the API key needs the App Manager or Admin role (Users and Access > Integrations)" >&2
  exit 1
fi
ipa=("$work"/export/*.ipa)
[ -f "${ipa[0]}" ] || { echo "::error::No IPA exported" >&2; exit 1; }
mv "${ipa[0]}" "$out/Postino.ipa"
