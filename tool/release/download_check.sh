#!/bin/bash
# Checks the download page (#173), hand-written HTML published as the bucket's index.html: lang="it", the
# __VERSION__ placeholder the workflow replaces, the download links and the guide link, and no HTML parser
# errors (xmllint's HTML4 parser, so the HTML5 <main> is the one tag it may not know). A typo stops the release
# before anything is published. The versioned links are checked with the placeholder still in.
# Usage: download_check.sh [download.html]
set -euo pipefail
html=${1:-docs/download/index.html}
ok=1
grep -q '<html lang="it">' "$html" || { echo "$html: no <html lang=\"it\">"; ok=0; }
grep -q '__VERSION__' "$html" || { echo "$html: no __VERSION__ placeholder"; ok=0; }
for href in macos/latest/Postino.dmg android/latest/Postino.apk \
  'macos/__VERSION__/Postino-__VERSION__.dmg' 'android/__VERSION__/Postino-__VERSION__.apk' guida/index.html; do
  grep -qE "<a [^>]*href=\"$href\"" "$html" || { echo "$html: missing link $href"; ok=0; }
done
command -v xmllint > /dev/null || { echo "xmllint not found"; exit 1; }
errors=$(xmllint --html --noout "$html" 2>&1 | grep 'parser error' | grep -v 'Tag main invalid' || true)
[ -z "$errors" ] || { echo "$html: $errors"; ok=0; }
[ "$ok" = 1 ] || exit 1
echo "download ok"
