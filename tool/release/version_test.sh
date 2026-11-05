#!/bin/bash
# Self-check of version.sh, run by ci.yml: the tag must equal v + the pubspec.yaml version, and a manual
# (branch) run is allowed only from main.
set -euo pipefail
cd "$(dirname "$0")/../.."
fails() { if "$@" tool/release/version.sh > /dev/null 2>&1; then echo "passed but should fail: $*"; exit 1; fi; }

version=$(env GITHUB_REF_TYPE=branch GITHUB_REF=refs/heads/main tool/release/version.sh)
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "bad version: $version"; exit 1; }
env GITHUB_REF_TYPE=tag GITHUB_REF_NAME="v$version" tool/release/version.sh > /dev/null
fails env GITHUB_REF_TYPE=tag GITHUB_REF_NAME="v$version.1"
fails env GITHUB_REF_TYPE=branch GITHUB_REF=refs/heads/feature
echo "version.sh ok ($version)"
