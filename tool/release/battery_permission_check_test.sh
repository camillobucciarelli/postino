#!/bin/bash
# Self-check of battery_permission_check.sh, run by ci.yml: a stub aapt2 prints canned permissions; the site's APK
# passes only with REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, the store's only without it, and a failing aapt2 fails both.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/build-tools/99.0.0"
aapt="$tmp/build-tools/99.0.0/aapt2"

aapt_prints() { printf '#!/bin/bash\ncat <<EOF\n%s\nEOF\n' "$1" > "$aapt"; chmod +x "$aapt"; }
passes() { ANDROID_HOME="$tmp" tool/release/battery_permission_check.sh app.apk "$1" > /dev/null 2>&1 || { echo "should pass: $2"; exit 1; }; }
fails() { if ANDROID_HOME="$tmp" tool/release/battery_permission_check.sh app.apk "$1" > /dev/null 2>&1; then echo "should fail: $2"; exit 1; fi; }

aapt_prints "package: com.cbucciarelli.postino
uses-permission: name='android.permission.INTERNET'
uses-permission: name='android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'"
passes site "site with the permission"
fails store "store with the permission"
aapt_prints "package: com.cbucciarelli.postino
uses-permission: name='android.permission.INTERNET'"
passes store "store without the permission"
fails site "site without the permission"
fails other "unknown flavor"
printf '#!/bin/bash\nexit 1\n' > "$aapt"
fails store "aapt2 fails"
fails site "aapt2 fails"
