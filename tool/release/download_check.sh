#!/bin/bash
# Checks the website (#173, #254), hand-written files that release.yml publishes at the bucket root: the product page
# in Italian (index.html) and English (en/index.html), with the __VERSION__ placeholder the workflow replaces; the
# privacy policy (privacy.html, en/privacy.html); style.css and the local fonts with their OFL licenses; the invitees'
# guide, served as guida/index.html with the same style.css. Logo and favicon are assets/brand's own files, published
# under brand/.
# Each page: its lang, the switch to its twin in the other language (hreflang), the stylesheet, the «Buy me a coffee»
# pill, no HTML parser errors (xmllint's HTML4 parser, so the HTML5 header/main/footer are the tags it may not know).
# Product pages: download, guide and privacy links. Every page and the guide: every link and url() leads to a file
# here, to assets/brand, to the guide or to a released download, the site's own absolute URLs included; nothing is
# loaded from elsewhere (no script, inline style, srcset, @import, single-quoted link) and no host but buymeacoffee.com
# (only as a link, with its rel) and the site's own is named in an attribute. A typo stops the release before anything is published.
# Usage: download_check.sh [site dir] [guide]
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
dir=${1:-$root/docs/download}
guide=${2:-$root/docs/guida-invitati/index.html}
site=postino.camillobucciarelli.dev
ok=1
fail() { echo "$1"; ok=0; }
has() { grep -qF -- "$2" "$1" || fail "$1: missing $2"; }
bmc='href="https://buymeacoffee.com/camillobucciarelli" rel="noopener noreferrer"'

page() { # <file> <lang> <twin's lang> <twin, relative> <site root, relative>
  has "$dir/$1" "<html lang=\"$2\">"
  has "$dir/$1" "<a href=\"$4\" hreflang=\"$3\" lang=\"$3\">"
  has "$dir/$1" "<link rel=\"stylesheet\" href=\"$5style.css\">"
  has "$dir/$1" "<a class=\"sponsor\" $bmc><span aria-hidden=\"true\">☕</span> Buy me a coffee</a>"
  errors=$(xmllint --html --noout "$dir/$1" 2>&1 | grep 'parser error' | grep -vE 'Tag (header|main|footer) invalid' || true)
  [ -z "$errors" ] || fail "$dir/$1: $errors"
}
product() { # <file> <site root, relative>
  has "$dir/$1" '__VERSION__'
  for href in macos/latest/Postino.dmg android/latest/Postino.apk 'macos/__VERSION__/Postino-__VERSION__.dmg' \
    'android/__VERSION__/Postino-__VERSION__.apk' guida/index.html; do
    has "$dir/$1" "href=\"$2$href\""
  done
  has "$dir/$1" 'href="privacy.html"'
}
links() { # <file> <its path on the bucket> [mailto: when allowed]
  local base path url host
  base=$(dirname "$2")
  if grep -nE "<script|<style|<iframe|<object|<embed|[[:space:]]style=|srcset=|@import|(href|src)='" "$1"; then
    fail "$1: loads or links something in a form this check does not read"
  fi
  # Hosts in any attribute (script, inline style and srcset are refused above, so nothing else loads); text may name
  # one, as the Gmail scope does in the privacy policy.
  while read -r host; do
    case $host in
      buymeacoffee.com | "$site") ;;
      *) fail "$1: names the host $host" ;;
    esac
  done < <(grep -oE '="[^"]*"' "$1" | grep -oE '//[A-Za-z0-9.-]+' | sed 's|^//||' | sort -u)
  [ "$(grep -o 'buymeacoffee\.com' "$1" | wc -l)" = "$(grep -oF "$bmc" "$1" | wc -l)" ] ||
    fail "$1: buymeacoffee.com other than as a link with rel=\"noopener noreferrer\""
  while read -r url; do
    case $url in
      https://buymeacoffee.com/camillobucciarelli) continue ;;
      mailto:*) [ "${3:-}" = mailto: ] || fail "$1: mail link $url"; continue ;;
      "https://$site/"*) path=${url#https://"$site"/} ;;
      *:* | //*) fail "$1: external or unknown link $url"; continue ;;
      *) path="$base/$url"; path=${path#./}; path=${path/#en\/..\//}; path=${path/#guida\/..\//} ;;
    esac
    case $path in
      guida/index.html | macos/latest/Postino.dmg | android/latest/Postino.apk) ;;
      'macos/__VERSION__/Postino-__VERSION__.dmg' | 'android/__VERSION__/Postino-__VERSION__.apk') ;;
      brand/*) [ -f "$root/assets/brand/${path#brand/}" ] || fail "$1: $url is not in assets/brand" ;;
      *) [ -f "$dir/$path" ] || fail "$1: $url is not a file of the site" ;;
    esac
  done < <(grep -oE '(href|src)="[^"]*"' "$1" | sed -E 's/^[a-z]+="(.*)"$/\1/')
}

command -v xmllint > /dev/null || { echo "xmllint not found"; exit 1; }
page index.html it en en/index.html ''
page en/index.html en it ../index.html ../
page privacy.html it en en/privacy.html ''
page en/privacy.html en it ../privacy.html ../
product index.html ''
product en/index.html ../
has "$dir/privacy.html" 'href="index.html"'
has "$dir/en/privacy.html" 'href="index.html"'
for f in index.html en/index.html privacy.html en/privacy.html; do links "$dir/$f" "$f"; done
links "$guide" guida/index.html mailto:
has "$guide" '<link rel="stylesheet" href="../style.css">'
# Published as they are: a placeholder there would show.
for f in "$dir/privacy.html" "$dir/en/privacy.html" "$dir/style.css" "$guide"; do
  if grep -n '__VERSION__' "$f"; then fail "$f: __VERSION__ is replaced only in the product pages"; fi
done
while read -r url; do
  [ -f "$dir/$url" ] || fail "$dir/style.css: url($url) is not a file of the site"
done < <(grep -oE 'url\([^)]*\)' "$dir/style.css" | sed -E 's/^url\("?([^")]*)"?\)$/\1/')
if grep -nE '//|@import' "$dir/style.css"; then fail "$dir/style.css: loads something from elsewhere"; fi
for font in caprasimo figtree; do
  grep -qF 'SIL Open Font License, Version 1.1' "$dir/fonts/$font-OFL.txt" 2> /dev/null ||
    fail "$dir/fonts/$font-OFL.txt: no OFL"
done

[ "$ok" = 1 ] || exit 1
echo "download ok"
