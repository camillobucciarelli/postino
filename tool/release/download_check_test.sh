#!/bin/bash
# Self-check of download_check.sh, run by ci.yml: the real site passes, and each kind of slip (third-party font or
# script, link to a missing file, Buy me a coffee without its rel or gone, wrong lang, missing switch to the twin,
# lost download link, missing font or license, broken markup) fails.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
site=docs/download

tool/release/download_check.sh "$site" > /dev/null || { echo "the real site should pass"; exit 1; }
fails() { # <what> <file> <sed on it, or "rm">
  rm -rf "$tmp/s"
  cp -R "$site" "$tmp/s"
  if [ "$3" = rm ]; then rm "$tmp/s/$2"; else sed -E "$3" "$site/$2" > "$tmp/s/$2"; fi
  if tool/release/download_check.sh "$tmp/s" > /dev/null 2>&1; then echo "should fail: $1"; exit 1; fi
}
fails "Google Fonts link" index.html 's|</head>|<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Figtree">\n</head>|'
fails "third-party script" en/privacy.html 's|</body>|<script src="https://example.com/a.js"></script>\n</body>|'
fails "@import in the stylesheet" style.css '1s|^|@import url(https://fonts.googleapis.com/css2?family=Figtree);\n|'
fails "missing font file" fonts/figtree-latin.woff2 rm
fails "missing license" fonts/caprasimo-OFL.txt rm
fails "link to a missing file" index.html 's|src="brand/icon.svg"|src="brand/logo.svg"|'
fails "Buy me a coffee pill without rel" privacy.html 's| rel="noopener noreferrer"><span| rel="noopener"><span|'
fails "support link without rel" index.html 's| rel="noopener noreferrer">offrirmi|>offrirmi|'
fails "Buy me a coffee pill gone" en/index.html 's|class="sponsor" ||'
fails "lang" en/index.html 's|<html lang="en">|<html lang="it">|'
fails "switch to the twin" en/privacy.html 's|href="../privacy.html" hreflang="it"|href="../index.html" hreflang="it"|'
fails "download link" en/index.html 's|\.\./android/latest/Postino.apk|android/latest/Postino.apk|'
fails "broken markup" privacy.html 's|</ul>|</strong></ul>|'
echo "download_check.sh ok"
