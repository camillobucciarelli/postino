#!/bin/bash
# Every restricted entitlement the app is signed with must be allowed by its provisioning profile, or AMFI
# refuses to launch the app on the user's Mac although notarization and spctl pass. TN3125: on macOS only the
# com.apple.security.* entitlements (App Sandbox, Hardened Runtime, get-task-allow, application-groups) are
# unrestricted; every other one is restricted. The profile's values are an allowlist with wildcards (<team>.*).
# Usage: entitlements_check.sh <signed entitlements plist> <decoded profile plist>
set -euo pipefail
signed=${1:?usage: entitlements_check.sh <entitlements> <profile>}
profile=${2:?usage: entitlements_check.sh <entitlements> <profile>}
fail() { echo "::error::$1 (#270)" >&2; exit 1; }
print() { /usr/libexec/PlistBuddy -c "Print :$1" "$2" 2> /dev/null; }
# An array prints as "Array {", one element per line, "}": its elements; anything else is one value.
values() {
  local out
  out=$(print "$1" "$2") || return 1
  if [[ $out == 'Array {'* ]]; then sed -e '1d' -e '$d' -e 's/^ *//' <<< "$out"; else echo "$out"; fi
}

# plutil's XML puts top-level keys at one tab of indentation.
keys=$(plutil -convert xml1 -o - "$signed" | sed -n 's/^\t<key>\(.*\)<\/key>$/\1/p')
while IFS= read -r key; do
  [[ -z $key || $key == com.apple.security.* ]] && continue
  allowed=$(values "Entitlements:$key" "$profile") || fail "The profile does not allow the entitlement $key"
  while IFS= read -r value; do
    ok=
    while IFS= read -r pattern; do
      # shellcheck disable=SC2053 # the profile's value is a pattern, e.g. <team>.*
      [[ $value == $pattern ]] && ok=1 && break
    done <<< "$allowed"
    [ -n "$ok" ] || fail "The profile does not allow $key = $value"
  done < <(values "$key" "$signed")
done <<< "$keys"
echo "entitlements_check.sh ok"
