#!/bin/bash
# Self-check of version_json.sh, run by ci.yml: the file the app reads, and the URLs it would refuse.
set -euo pipefail
cd "$(dirname "$0")/../.."
expect() { [ "$(tool/release/version_json.sh "$1" "$2")" = "$3" ] || { echo "version_json.sh $1 $2 != $3"; exit 1; }; }
fails() { if tool/release/version_json.sh "$1" "$2" > /dev/null 2>&1; then echo "passed but should fail: $1 $2"; exit 1; fi; }

expect 1.3.0 https://postino.example/android/1.3.0/Postino-1.3.0.apk \
  '{"version":"1.3.0","build":1003000,"url":"https://postino.example/android/1.3.0/Postino-1.3.0.apk"}'
expect 1.2.1 itms-beta:// '{"version":"1.2.1","build":1002001,"url":"itms-beta://"}'
fails 1.3 https://postino.example/p.apk
fails 1.3.0 http://postino.example/p.apk
fails 1.3.0 'https://postino.example/"p'
fails 1.3.0 'https://postino.example/ p'
fails 1.3.0 javascript:alert
echo "version_json.sh ok"
