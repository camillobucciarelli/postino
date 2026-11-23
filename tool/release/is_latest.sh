#!/bin/bash
# Prints "yes" when <X.Y.Z> is the highest vX.Y.Z tag on origin, "no" otherwise, so a hotfix of an older line
# or the re-run of an old tag never moves the "latest" download back. Fails (instead of answering "no")
# when origin can't be read, so a network error never skips the "latest" upload silently.
# Usage: latest=$(is_latest.sh <X.Y.Z>)
set -euo pipefail
version=${1:?usage: is_latest.sh <X.Y.Z>}

highest=$("$(dirname "$0")/highest_version.sh")
if [ "$version" = "$highest" ]; then echo yes; else echo no; fi
