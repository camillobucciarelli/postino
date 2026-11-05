#!/bin/bash
# Checks that the published guide for invitees (#123), hand-written HTML, still says what its Markdown source says:
# same headings at the same levels, same links, same words. No pandoc on the runner and no Markdown package in the
# project, so the HTML is kept by hand and this keeps the two from drifting. Also: lang="it" and no HTML parser
# errors (xmllint's HTML4 parser, so the HTML5 <main> is the one tag it may not know).
# Usage: guide_check.sh [guide.md] [guide.html]
set -euo pipefail
md=${1:-docs/guida-invitati.md}
html=${2:-docs/guida-invitati/index.html}
ok=1
differ() { # <what> <markdown side> <html side>
  if ! diff <(printf '%s\n' "$2") <(printf '%s\n' "$3") > /dev/null; then
    echo "$md and $html differ in $1:"
    diff <(printf '%s\n' "$2") <(printf '%s\n' "$3") | sed 's/^/  /' || true
    ok=0
  fi
}

differ headings \
  "$(sed -nE 's/^(#+) (.*)/\1 \2/p' "$md" | awk '{ n = length($1); $1 = n; print }')" \
  "$(sed -nE 's|.*<h([1-6])>(.*)</h[1-6]>.*|\1 \2|p' "$html")"
differ links \
  "$(grep -oE '\]\([^)]*\)' "$md" | sed -E 's/^\]\((.*)\)$/\1/')" \
  "$(grep -oE 'href="[^"]*"' "$html" | sed -E 's/^href="(.*)"$/\1/')"
# Prose: Markdown without its markup, HTML <main> without its tags, word by word.
differ words \
  "$(grep -v '^<!--' "$md" | sed -E 's/^#+ //; s/^[0-9]+\. //; s/^- //; s/\*\*//g; s/`//g; s/\[([^]]*)\]\([^)]*\)/\1/g' | tr -s '[:space:]' '\n' | sed '/^$/d')" \
  "$(sed -n '/<main>/,/<\/main>/p' "$html" | sed -E 's/<[^>]*>//g' | tr -s '[:space:]' '\n' | sed '/^$/d')"

grep -q '<html lang="it">' "$html" || { echo "$html: no <html lang=\"it\">"; ok=0; }
errors=$(xmllint --html --noout "$html" 2>&1 | grep 'parser error' | grep -v 'Tag main invalid' || true)
[ -z "$errors" ] || { echo "$html: $errors"; ok=0; }

[ "$ok" = 1 ] || exit 1
echo "guide ok"
