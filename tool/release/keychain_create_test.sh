#!/bin/bash
# Self-check of keychain_create.sh, run by ci.yml, with a fake `security` (and `pkill`) in the PATH: the identities it
# exports for the DMG (Developer ID hash) and for the Mac App Store (#325: Apple Distribution hash, installer full
# name), only the team's, and the productbuild access to the key only when an installer identity is asked for.
set -euo pipefail
script=$(cd "$(dirname "$0")" && pwd)/keychain_create.sh
tmp=$(mktemp -d "${TMPDIR:-/tmp}/keychain-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
cat > "$tmp/bin/security" <<'FAKE'
#!/bin/bash
case $1 in
  find-identity)
    echo '  1) AAAA "Developer ID Application: Someone (TEAM1)"'
    echo '  2) BBBB "Apple Distribution: Someone (TEAM1)"'
    if [[ $* != *codesigning* ]]; then
      echo '  3) DDDD "Mac Installer Distribution: Someone Else (OTHER)"'
      echo '  4) CCCC "3rd Party Mac Developer Installer: Someone (TEAM1)"'
    fi
    echo '     4 valid identities found' ;;
  find-certificate) echo 5B45F61068B29FCC8FFFF1A7E99B78DA9E9C4635 ;;
  import) echo "$*" >> "$IMPORTS" ;;
esac
FAKE
printf '#!/bin/bash\nexit 1\n' > "$tmp/bin/pkill"
chmod +x "$tmp/bin/security" "$tmp/bin/pkill"

# run <team> [VAR=value...]: the exported environment on stdout, the exit code kept.
run() {
  local team=$1
  shift
  rm -f "$tmp/env" "$tmp/imports"
  env PATH="$tmp/bin:$PATH" RUNNER_TEMP="$tmp" GITHUB_ENV="$tmp/env" IMPORTS="$tmp/imports" \
    MACOS_CERTIFICATE_P12_BASE64=eA== MACOS_CERTIFICATE_PASSWORD=p APPLE_TEAM_ID="$team" "$@" "$script" > /dev/null 2>&1
}
expect() { [ "$(cat "$tmp/env")" = "$2" ] || { echo "$1: got $(cat "$tmp/env")"; exit 1; }; }
store=(SIGNING_CERTIFICATE='Apple Distribution|3rd Party Mac Developer Application'
  INSTALLER_CERTIFICATE='3rd Party Mac Developer Installer|Mac Installer Distribution')

run TEAM1
expect "DMG" "SIGNING_IDENTITY=AAAA"
! grep -q productbuild "$tmp/imports" || { echo "DMG: productbuild gets the key"; exit 1; }
run TEAM1 "${store[@]}"
expect "Store" "SIGNING_IDENTITY=BBBB
INSTALLER_IDENTITY=3rd Party Mac Developer Installer: Someone (TEAM1)"
grep -q -- '-T /usr/bin/productbuild' "$tmp/imports" || { echo "Store: productbuild has no access to the key"; exit 1; }
# OTHER's installer is listed first: never taken for TEAM1, and TEAM1's identities never for OTHER.
if run OTHER "${store[@]}"; then echo "OTHER has no signing identity: should fail"; exit 1; fi
if run TEAM1 SIGNING_CERTIFICATE='Apple Distribution' INSTALLER_CERTIFICATE='Mac Installer Distribution'; then
  echo "TEAM1 has no Mac Installer Distribution identity: should fail"
  exit 1
fi
echo "keychain_create.sh ok"
