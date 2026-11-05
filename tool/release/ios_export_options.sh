#!/bin/bash
# Prints the exportOptionsPlist of the TestFlight build: App Store Connect distribution, signed by Xcode itself
# (cloud-managed "Apple Distribution" certificate and App Store profile, created through the API key), no upload
# here (testflight_upload.sh does it, so the IPA is kept and checked first).
# Usage: ios_export_options.sh <team-id> > ExportOptions.plist
set -euo pipefail
team=${1:?usage: ios_export_options.sh <team-id>}

if ! [[ $team =~ ^[A-Z0-9]{10}$ ]]; then
  echo "::error::Not an Apple team ID: $team" >&2
  exit 1
fi
cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>export</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>$team</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST
