#!/bin/bash
# Self-check of guide_check.sh, run by ci.yml: the real guide passes, and each kind of drift between its Markdown
# and its HTML (heading level, link, word, lang, broken markup) fails.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
md=docs/guida-invitati.md
html=docs/guida-invitati/index.html

tool/release/guide_check.sh "$md" "$html" > /dev/null || { echo "the real guide should pass"; exit 1; }
fails() { # <what> <sed on md> <sed on html>
  sed -E "$2" "$md" > "$tmp/g.md"
  sed -E "$3" "$html" > "$tmp/g.html"
  if tool/release/guide_check.sh "$tmp/g.md" "$tmp/g.html" > /dev/null 2>&1; then echo "should fail: $1"; exit 1; fi
}
fails "heading level" 's/^## macOS$/### macOS/' ''
fails "link target" '' 's|android/latest/Postino.apk|android/1.0.0/Postino.apk|'
fails "word" 's/rileggila/leggila/' ''
fails "lang" '' 's/<html lang="it">/<html>/'
fails "broken markup" "" "s|</ol>|</strong></ol>|"
echo "guide_check.sh ok"
