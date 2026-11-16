#!/bin/bash
# Fails unless the APK's merged manifest declares REQUEST_IGNORE_BATTERY_OPTIMIZATIONS as its flavor wants (#345,
# ADR 0023): the APK from the site does (the system's one-tap dialog), the Google Play variant does not (Play allows
# that permission only to apps whose core function Doze breaks).
# Usage: battery_permission_check.sh <apk> site|store
set -euo pipefail
apk=${1:?usage: battery_permission_check.sh <apk> site|store}
flavor=${2:?usage: battery_permission_check.sh <apk> site|store}
: "${ANDROID_HOME:?}"
case "$flavor" in
  site) want=yes ;;
  store) want=no ;;
  *) echo "::error::Unknown flavor $flavor" >&2; exit 1 ;;
esac

aapt2=$(ls "$ANDROID_HOME"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -n 1 || true)
test -n "$aapt2" || { echo "::error::No aapt2 in $ANDROID_HOME/build-tools" >&2; exit 1; }
# Read first: a failing aapt2 stops here instead of looking like a manifest without the permission.
permissions=$("$aapt2" dump permissions "$apk")
if grep -q "name='android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'" <<< "$permissions"; then have=yes; else have=no; fi
[ "$have" = "$want" ] || {
  echo "::error::$apk ($flavor): REQUEST_IGNORE_BATTERY_OPTIMIZATIONS declared: $have, expected $want" >&2
  exit 1
}
