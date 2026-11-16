#!/bin/bash
# The Mac App Store variant (#325, ADR 0021) before its upload, verify.sh's twin: the bundle the Store accepts
# (store_bundle_check.sh), signed with Apple Distribution and the Mac App Store profile that authorizes its keychain
# access group and entitlements (profile_check.sh), readable by everyone once root owns it (readable_check.sh), and
# the .pkg signed with the Mac Installer certificate.
# No Gatekeeper or notarization here: the Store re-signs the app. App Store Connect checks the rest at upload.
# Usage: APPLE_TEAM_ID=<team> verify_store.sh <app> <pkg>
set -euo pipefail
app=${1:?usage: verify_store.sh <app> <pkg>}
pkg=${2:?usage: verify_store.sh <app> <pkg>}
: "${APPLE_TEAM_ID:?}"
here=$(dirname "$0")
fail() { echo "::error::$1 (#325)" >&2; exit 1; }

codesign --verify --deep --strict --verbose=2 "$app"
"$here/store_bundle_check.sh" "$app"
"$here/profile_check.sh" "$app" app-store
"$here/readable_check.sh" "$app"
authority=$(codesign -dvv "$app" 2>&1 | sed -n 's/^Authority=//p' | head -n 1)
[[ $authority == "Apple Distribution: "* || $authority == "3rd Party Mac Developer Application: "* ]] ||
  fail "$app is signed by $authority, not Apple Distribution"
# Xcode's ad-hoc "Sign to Run Locally" adds it; App Store Connect refuses it.
! codesign -d --entitlements - --xml "$app" 2> /dev/null | grep -q get-task-allow || fail "get-task-allow in the entitlements"
installer=$(pkgutil --check-signature "$pkg" | sed -n 's/^ *1\. //p') || fail "$pkg is not signed"
[[ $installer == "3rd Party Mac Developer Installer: "* || $installer == "Mac Installer Distribution: "* ]] ||
  fail "$pkg is signed by $installer, not the Mac Installer certificate"
echo "verify_store.sh ok"
