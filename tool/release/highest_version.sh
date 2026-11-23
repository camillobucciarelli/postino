#!/bin/bash
# Prints the highest released version X.Y.Z, from the vX.Y.Z tags on origin (numeric order: 1.10.0 > 1.9.0).
# Fails (instead of printing nothing) when origin can't be read or has no such tag.
# Usage: highest=$(highest_version.sh)
set -euo pipefail

tags=$(git ls-remote --tags --refs origin 'v*.*.*')
highest=$(sed -n 's|.*refs/tags/v\([0-9]*\.[0-9]*\.[0-9]*\)$|\1|p' <<< "$tags" | sort -t . -k 1,1n -k 2,2n -k 3,3n | tail -n 1)
test -n "$highest" || { echo "::error::No vX.Y.Z tag on origin" >&2; exit 1; }
echo "$highest"
