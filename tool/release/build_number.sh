#!/bin/bash
# Prints the build number of version X.Y.Z: X*1000000 + Y*1000 + Z, so it grows with every release.
# Sparkle (#122) compares CFBundleVersion, not the X.Y.Z shown to the user, and pubspec.yaml's "+1" never changes.
# Fails when Y or Z reaches 1000, where the number would stop growing with the version.
# Usage: build=$(build_number.sh <X.Y.Z>)
set -euo pipefail
version=${1:?usage: build_number.sh <X.Y.Z>}

if ! [[ $version =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "::error::Not an X.Y.Z version: $version" >&2
  exit 1
fi
major=$((10#${BASH_REMATCH[1]}))
minor=$((10#${BASH_REMATCH[2]}))
patch=$((10#${BASH_REMATCH[3]}))
if [ "$minor" -ge 1000 ] || [ "$patch" -ge 1000 ]; then
  echo "::error::$version: minor and patch must stay below 1000 for the build number" >&2
  exit 1
fi
echo $((major * 1000000 + minor * 1000 + patch))
