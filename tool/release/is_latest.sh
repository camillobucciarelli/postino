#!/bin/bash
# Exits 0 when <X.Y.Z> is the highest vX.Y.Z tag on origin, so a hotfix of an older line or the re-run of
# an old tag never moves the "latest" download back.
# Usage: is_latest.sh <X.Y.Z>
set -euo pipefail
version=${1:?usage: is_latest.sh <X.Y.Z>}

tags=$(git ls-remote --tags --refs origin 'v*.*.*')
highest=$(sed -n 's|.*refs/tags/v\([0-9]*\.[0-9]*\.[0-9]*\)$|\1|p' <<< "$tags" | sort -t . -k 1,1n -k 2,2n -k 3,3n | tail -n 1)
[ "$version" = "$highest" ]
