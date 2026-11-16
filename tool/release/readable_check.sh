#!/bin/bash
# Every file and folder of the app is readable by everyone (#340): productbuild gives the payload to root, so a file
# readable only by its owner becomes readable only by root once installed, and App Store Connect refuses the .pkg
# (90255). Folders also need the search bit.
# Usage: readable_check.sh <app>
set -euo pipefail
app=${1:?usage: readable_check.sh <app>}
[ -d "$app" ] || { echo "::error::No app at $app (#340)" >&2; exit 1; }
unreadable=$(find "$app" \( ! -perm -o+r -o \( -type d ! -perm -o+x \) \) -print)
[ -z "$unreadable" ] || { echo "::error::Not readable by everyone (#340): ${unreadable//$'\n'/, }" >&2; exit 1; }
