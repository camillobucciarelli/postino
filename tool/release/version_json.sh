#!/bin/bash
# Prints the version file (#287) that installed Android and iOS copies read from <platform>/latest/version.json:
# the version, its build number (build_number.sh, what the app compares with its own) and where it is downloaded.
# The app refuses any URL but https:// (on iOS the App Store page, #323), so this does too, before anything is published.
# Usage: version_json.sh <X.Y.Z> <url> > version.json
set -euo pipefail
version=${1:?usage: version_json.sh <X.Y.Z> <url>}
url=${2:?usage: version_json.sh <X.Y.Z> <url>}

build=$("$(dirname "$0")/build_number.sh" "$version")
if ! [[ $url =~ ^https://[^\"\\[:space:]]*$ ]]; then
  echo "::error::Not an https:// URL: $url" >&2
  exit 1
fi
printf '{"version":"%s","build":%s,"url":"%s"}\n' "$version" "$build" "$url"
