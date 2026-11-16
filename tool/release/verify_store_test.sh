#!/bin/bash
# Self-check of verify_store.sh, run by ci.yml: its own checks (who signed the app and the .pkg, no get-task-allow)
# with a fake codesign and pkgutil in the PATH. The bundle and profile checks it runs have their own self-checks, so
# here they are stubs next to a copy of the script.
set -euo pipefail
src=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/verify-store-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/release"
cp "$src/verify_store.sh" "$tmp/release/"
for stub in store_bundle_check.sh profile_check.sh readable_check.sh; do printf '#!/bin/bash\nexit 0\n' > "$tmp/release/$stub"; done
cat > "$tmp/bin/codesign" <<'FAKE'
#!/bin/bash
case "$*" in
  *--verify*) exit 0 ;;
  *-dvv*) echo "Authority=$FAKE_AUTHORITY" >&2 ;;
  *--entitlements*) echo "<plist><dict>$FAKE_ENTITLEMENTS</dict></plist>" ;;
esac
FAKE
cat > "$tmp/bin/pkgutil" <<'FAKE'
#!/bin/bash
[ -n "$FAKE_INSTALLER" ] || { echo "Status: no signature"; exit 1; }
printf 'Package "x.pkg":\n   Status: signed by a certificate trusted by macOS\n   Certificate Chain:\n    1. %s\n    2. Apple Worldwide Developer Relations Certification Authority\n' "$FAKE_INSTALLER"
FAKE
chmod +x "$tmp"/bin/* "$tmp"/release/*.sh

# check <authority> <installer> [entitlements]
check() {
  PATH="$tmp/bin:$PATH" APPLE_TEAM_ID=TEAM FAKE_AUTHORITY=$1 FAKE_INSTALLER=$2 FAKE_ENTITLEMENTS=${3:-} \
    "$tmp/release/verify_store.sh" "$tmp/Postino.app" "$tmp/Postino.pkg" 2>&1
}
passes() { check "$2" "$3" > /dev/null || { echo "should pass: $1: $(check "$2" "$3")"; exit 1; }; }
fails() { # <case> <what the error must name> <authority> <installer> [entitlements]
  local out
  if out=$(check "$3" "$4" "${5:-}"); then echo "should fail: $1"; exit 1; fi
  grep -qF -- "$2" <<< "$out" || { echo "$1: the error does not name $2: $out"; exit 1; }
}
dist="Apple Distribution: Someone (TEAM)"
installer="3rd Party Mac Developer Installer: Someone (TEAM)"

passes "Apple Distribution and Mac Installer" "$dist" "$installer"
passes "legacy names" "3rd Party Mac Developer Application: Someone (TEAM)" "Mac Installer Distribution: Someone (TEAM)"
fails "Developer ID app" 'not Apple Distribution' "Developer ID Application: Someone (TEAM)" "$installer"
fails "Developer ID installer" 'not the Mac Installer' "$dist" "Developer ID Installer: Someone (TEAM)"
fails "unsigned pkg" 'is not signed' "$dist" ''
fails "get-task-allow" 'get-task-allow' "$dist" "$installer" '<key>com.apple.security.get-task-allow</key><true/>'
echo "verify_store.sh ok"
