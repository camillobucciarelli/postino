#!/bin/bash
# Self-check of readable_check.sh, run by ci.yml: a fake app with one file or folder at a time made unreadable, and
# the app as sign_app.sh leaves it (fake codesign in the PATH) from a profile written with release.yml's umask 077 (#340).
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'chmod -R u+rwx "$tmp"; rm -rf "$tmp"' EXIT
app="$tmp/Postino.app"
reset() {
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks/X.framework/Versions/A"
  printf x > "$app/Contents/MacOS/Postino"
  printf x > "$app/Contents/Frameworks/X.framework/Versions/A/X"
  plutil -create xml1 "$app/Contents/Info.plist"
  plutil -insert CFBundleIdentifier -string app.postino "$app/Contents/Info.plist"
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
(umask 077 && ln -s A "$app/Contents/Frameworks/X.framework/Versions/Current")
passes "symlink with an owner-only mode"
chmod 600 "$app/Contents/MacOS/Postino"
fails "file only its owner reads" "Contents/MacOS/Postino"
reset
chmod 700 "$app/Contents/Frameworks/X.framework"
fails "folder only its owner searches" "X.framework"
reset
chmod 744 "$app/Contents/Frameworks/X.framework"
fails "folder readable but not searchable" "X.framework"
if tool/release/readable_check.sh "$tmp/none.app" 2> /dev/null; then echo "should fail: no app"; exit 1; fi

reset
mkdir "$tmp/bin"
printf '#!/bin/bash\ncase "$*" in *--entitlements\\ -*) echo "<plist><dict/></plist>" ;; esac\n' > "$tmp/bin/codesign"
chmod +x "$tmp/bin/codesign"
(umask 077 && printf x > "$tmp/profile")
PATH="$tmp/bin:$PATH" SIGNING_IDENTITY=X APPLE_TEAM_ID=TEAM PROVISION_PROFILE="$tmp/profile" \
  tool/release/sign_app.sh "$app" > /dev/null
[ -f "$app/Contents/embedded.provisionprofile" ] || { echo "sign_app.sh did not embed the profile"; exit 1; }
passes "profile written with umask 077, embedded by sign_app.sh"
echo "readable_check.sh ok"
