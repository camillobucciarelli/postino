#!/bin/bash
# Self-check of readable_check.sh, run by ci.yml: a fake app with one file or folder at a time made unreadable, and
# the profile installed by sign_app.sh's own line from a file written with the workflow's umask 077 (#340).
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'chmod -R u+rwx "$tmp"; rm -rf "$tmp"' EXIT
app="$tmp/Postino.app"
reset() {
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks/X.framework"
  printf x > "$app/Contents/MacOS/Postino"
  printf x > "$app/Contents/Frameworks/X.framework/X"
  chmod -R a+rX "$app"
}
check() { tool/release/readable_check.sh "$app" 2>&1; }
passes() { check > /dev/null || { echo "should pass: $1: $(check)"; exit 1; }; }
fails() { # $2: what the error must name
  local out
  if out=$(check); then echo "should fail: $1"; exit 1; fi
  grep -qF -- "$2" <<< "$out" || { echo "$1: the error does not name $2: $out"; exit 1; }
}

reset
passes "all readable"
chmod 600 "$app/Contents/MacOS/Postino"
fails "file only its owner reads" "Contents/MacOS/Postino"
reset
chmod 700 "$app/Contents/Frameworks/X.framework"
fails "folder only its owner searches" "X.framework"
reset
chmod 744 "$app/Contents/Frameworks/X.framework"
fails "folder readable but not searchable" "X.framework"
reset
# sign_app.sh's line, on a profile written as release.yml writes it.
line='install -m 644 "$profile" "$app/Contents/embedded.provisionprofile"'
grep -qxF "$line" tool/release/sign_app.sh || { echo "sign_app.sh no longer installs the profile with: $line"; exit 1; }
(umask 077 && printf x > "$tmp/profile")
profile="$tmp/profile" eval "$line"
passes "profile written with umask 077, installed by sign_app.sh"
if tool/release/readable_check.sh "$tmp/none.app" 2> /dev/null; then echo "should fail: no app"; exit 1; fi
echo "readable_check.sh ok"
