#!/bin/bash
# Prints "yes" when <X.Y.Z> is the highest vX.Y.Z tag on origin, "no" otherwise, so a hotfix of an older line
# or the re-run of an old tag never moves the "latest" download back. Fails (instead of answering "no")
# when origin can't be read, so a network error never skips the "latest" upload silently.
# Usage: latest=$(is_latest.sh <X.Y.Z>)
set -euo pipefail
version=${1:?usage: is_latest.sh <X.Y.Z>}

tags=$(git ls-remote --tags --refs origin 'v*.*.*')
highest=$(sed -n 's|.*refs/tags/v\([0-9]*\.[0-9]*\.[0-9]*\)$|\1|p' <<< "$tags" | sort -t . -k 1,1n -k 2,2n -k 3,3n | tail -n 1)
if [ "$version" = "$highest" ]; then echo yes; else echo no; fi
