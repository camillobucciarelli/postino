#!/bin/bash
# Checks the website (#173), hand-written files that release.yml publishes at the bucket root: the product page in
# Italian (index.html) and English (en/index.html), with the __VERSION__ placeholder the workflow replaces; the privacy
# policy (privacy.html, en/privacy.html); style.css and the local fonts with their OFL licenses. Logo and favicon are
# assets/brand's own files, published under brand/. Run from the repository root.
# Each page: its lang, the switch to its twin in the other language (hreflang), the stylesheet, the «Buy me a
# coffee» link, no HTML parser errors (xmllint's HTML4 parser, so the HTML5 header/main/footer are the tags it may
# not know). Product pages: download links, guide and privacy links. Whole site: every link and url() resolves to a
# file here, to assets/brand, to the guide or to a released download, and no host but buymeacoffee.com and the
# site's own is named: nothing from a third party (fonts, images, scripts) is loaded. A typo stops the release before
# anything is published. Usage: download_check.sh [site dir]
set -euo pipefail
dir=${1:-docs/download}
ok=1
fail() { echo "$dir/$1"; ok=0; }
has() { grep -qF -- "$2" "$dir/$1" || fail "$1: missing $2"; }
bmc='href="https://buymeacoffee.com/camillobucciarelli"'

page() { # <file> <lang> <twin's lang> <twin, relative> <site root, relative>
  has "$1" "<html lang=\"$2\">"
  has "$1" "<a href=\"$4\" hreflang=\"$3\" lang=\"$3\">"
  has "$1" "<link rel=\"stylesheet\" href=\"$5style.css\">"
  has "$1" "<a class=\"sponsor\" $bmc rel=\"noopener noreferrer\"><span aria-hidden=\"true\">☕</span> Buy me a coffee</a>"
  [ "$(grep -o "$bmc" "$dir/$1" | wc -l)" = "$(grep -o "$bmc rel=\"noopener noreferrer\"" "$dir/$1" | wc -l)" ] ||
    fail "$1: a Buy me a coffee link without rel=\"noopener noreferrer\""
  errors=$(xmllint --html --noout "$dir/$1" 2>&1 | grep 'parser error' | grep -vE 'Tag (header|main|footer) invalid' || true)
  [ -z "$errors" ] || fail "$1: $errors"
}
product() { # <file> <site root, relative>
  has "$1" '__VERSION__'
  for href in macos/latest/Postino.dmg android/latest/Postino.apk 'macos/__VERSION__/Postino-__VERSION__.dmg' \
    'android/__VERSION__/Postino-__VERSION__.apk' guida/index.html; do
    has "$1" "href=\"$2$href\""
  done
  has "$1" 'href="privacy.html"'
}

command -v xmllint > /dev/null || { echo "xmllint not found"; exit 1; }
page index.html it en en/index.html ''
page en/index.html en it ../index.html ../
page privacy.html it en en/privacy.html ''
page en/privacy.html en it ../privacy.html ../
product index.html ''
product en/index.html ../
has privacy.html 'href="index.html"'
has en/privacy.html 'href="index.html"'

# Every link: the two allowed hosts, or a path that is a file of the site, the guide or a released download.
for f in index.html en/index.html privacy.html en/privacy.html; do
  base=$(dirname "$f")
  while read -r url; do
    case $url in
      https://buymeacoffee.com/* | https://postino.camillobucciarelli.dev/*) continue ;;
      *:* | //*) fail "$f: external or unknown link $url"; continue ;;
    esac
    path="$base/$url"
    path=${path#./}
    path=${path#en/../}
    case $path in
      guida/index.html | macos/latest/Postino.dmg | android/latest/Postino.apk) ;;
      brand/*) [ -f "assets/brand/${path#brand/}" ] || fail "$f: $url is not in assets/brand" ;;
      'macos/__VERSION__/Postino-__VERSION__.dmg' | 'android/__VERSION__/Postino-__VERSION__.apk') ;;
      *) [ -f "$dir/$path" ] || fail "$f: $url is not a file of the site" ;;
    esac
  done < <(grep -oE '(href|src)="[^"]*"' "$dir/$f" | sed -E 's/^[a-z]+="(.*)"$/\1/')
done
while read -r url; do
  [ -f "$dir/$url" ] || fail "style.css: url($url) is not a file of the site"
done < <(grep -oE 'url\([^)]*\)' "$dir/style.css" | sed -E 's/^url\("?([^")]*)"?\)$/\1/')
if grep -nE 'https?:|@import' "$dir/style.css"; then fail "style.css: loads something from elsewhere"; fi
for font in caprasimo figtree; do
  grep -qF 'SIL Open Font License, Version 1.1' "$dir/fonts/$font-OFL.txt" 2> /dev/null || fail "fonts/$font-OFL.txt: no OFL"
done

[ "$ok" = 1 ] || exit 1
echo "download ok"
