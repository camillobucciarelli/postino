#!/bin/bash
# Self-check of build_number.sh, run by ci.yml: the build number grows with the version and refuses what would
# break that.
set -euo pipefail
cd "$(dirname "$0")/../.."
expect() { [ "$(tool/release/build_number.sh "$1")" = "$2" ] || { echo "build_number.sh $1 != $2"; exit 1; }; }
fails() { if tool/release/build_number.sh "$1" > /dev/null 2>&1; then echo "passed but should fail: $1"; exit 1; fi; }

expect 1.0.0 1000000
expect 1.0.1 1000001
expect 1.2.3 1002003
expect 1.999.999 1999999
expect 2.0.0 2000000
expect 1.08.09 1008009
fails 1.1000.0
fails 1.0.1000
fails 1.0
fails v1.0.0
echo "build_number.sh ok"
