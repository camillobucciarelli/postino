#!/bin/bash
# Prints the release version X.Y.Z from pubspec.yaml. On a tag build it fails unless the tag is vX.Y.Z,
# so a mismatched tag stops the release before any build; a manual run is allowed only from main.
set -euo pipefail

if [ "${GITHUB_EVENT_NAME:-}" = workflow_dispatch ] && [ "${GITHUB_REF:-}" != refs/heads/main ]; then
  echo "::error::Manual releases run only from main, not ${GITHUB_REF:-}" >&2
  exit 1
fi

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
