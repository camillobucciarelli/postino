#!/bin/bash
# Self-check of guide_check.sh, run by ci.yml: the real guide passes, and each kind of drift between its Markdown
# and its HTML (heading level, link target or text, unclosed or dropped link, word, lang, broken markup) fails.
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
fails "unclosed link" '' 's|ultima versione\)</a>|ultima versione)|'
fails "link turned into text" '' 's|<a (href="mailto:[^"]*">[^<]*)</a>|<span \1</span>|'
fails "link text" '' 's|>Postino per macOS \(file DMG, ultima versione\)</a>|>Postino</a> per macOS (file DMG, ultima versione)|'
echo "guide_check.sh ok"
