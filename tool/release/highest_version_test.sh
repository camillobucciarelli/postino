#!/bin/bash
# Self-check of highest_version.sh and is_latest.sh, run by ci.yml, against a local bare repository standing in for
# origin: numeric order (1.10.0 > 1.9.0), tags that are not exactly vX.Y.Z ignored, no tag or no origin fails.
set -euo pipefail
script=$(cd "$(dirname "$0")" && pwd)
fails() { if "$@" > /dev/null 2>&1; then echo "passed but should fail: $*"; exit 1; fi; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git init --quiet --bare "$tmp/origin.git"
git init --quiet "$tmp/work"
cd "$tmp/work"
git remote add origin "$tmp/origin.git"
fails "$script/highest_version.sh"
git -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m t
for tag in v1.9.0 v1.10.0 v1.10.1-rc1 v2.0 v1.2.30; do git tag "$tag"; done
git push --quiet origin --tags
test "$("$script/highest_version.sh")" = 1.10.0 || { echo "highest_version.sh: want 1.10.0"; exit 1; }
test "$("$script/is_latest.sh" 1.10.0)" = yes || { echo "is_latest.sh 1.10.0: want yes"; exit 1; }
test "$("$script/is_latest.sh" 1.9.0)" = no || { echo "is_latest.sh 1.9.0: want no"; exit 1; }
git remote set-url origin "$tmp/missing.git"
fails "$script/highest_version.sh"
fails "$script/is_latest.sh" 1.10.0
echo "highest_version.sh ok"
