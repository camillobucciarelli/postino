#!/bin/bash
# Self-check of version.sh, run by ci.yml: the tag must equal v + the pubspec.yaml version.
set -euo pipefail
cd "$(dirname "$0")/../.."
version=$(GITHUB_REF_TYPE=branch tool/release/version.sh)
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "bad version: $version"; exit 1; }
GITHUB_REF_TYPE=tag GITHUB_REF_NAME="v$version" tool/release/version.sh > /dev/null
if GITHUB_REF_TYPE=tag GITHUB_REF_NAME="v$version.1" tool/release/version.sh > /dev/null 2>&1; then
  echo "a mismatched tag passed"
  exit 1
fi
echo "version.sh ok ($version)"
