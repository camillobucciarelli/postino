#!/bin/bash
# Every file and folder of the app is readable by everyone (#340): productbuild gives the payload to root, so a file
# readable only by its owner becomes readable only by root once installed, and App Store Connect refuses the .pkg
# (90255). Folders also need the search bit. Symlinks are skipped: macOS ignores their own mode.
# Usage: readable_check.sh <app>
set -euo pipefail
app=${1:?usage: readable_check.sh <app>}
fail() { echo "::error::$1 (#340)" >&2; exit 1; }
[ -d "$app" ] || fail "No app at $app"
unreadable=$(find "$app" ! -type l \( ! -perm -o+r -o \( -type d ! -perm -o+x \) \) -print)
[ -z "$unreadable" ] || fail "Not readable by everyone: ${unreadable//$'\n'/, }"
