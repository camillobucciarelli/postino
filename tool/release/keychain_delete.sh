#!/bin/bash
# Undoes keychain_create.sh: restores the user search list and deletes the job keychain.
# Safe when keychain_create.sh failed halfway or never ran.
set -uo pipefail
: "${RUNNER_TEMP:?}"

keychain="$RUNNER_TEMP/release.keychain-db"
saved_list="$RUNNER_TEMP/keychain-search-list"

if [ -s "$saved_list" ]; then
  xargs security list-keychains -d user -s < "$saved_list"
fi
rm -f "$saved_list" "$RUNNER_TEMP/developer-id.p12"
if [ -f "$keychain" ]; then
  security delete-keychain "$keychain"
fi
