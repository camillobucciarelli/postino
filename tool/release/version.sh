#!/bin/bash
# Prints the release version X.Y.Z from pubspec.yaml. On a tag build it fails unless the tag is vX.Y.Z,
# so a mismatched tag stops the release before any build.
set -euo pipefail

version=$(sed -n 's/^version:[[:space:]]*\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' pubspec.yaml)
if [ -z "$version" ]; then
  echo "::error::No X.Y.Z version in pubspec.yaml" >&2
  exit 1
fi
if [ "${GITHUB_REF_TYPE:-}" = tag ] && [ "${GITHUB_REF_NAME:-}" != "v$version" ]; then
  echo "::error::Tag ${GITHUB_REF_NAME:-} does not match pubspec.yaml version $version" >&2
  exit 1
fi
echo "$version"
