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
# loaded from elsewhere (no script, inline style, srcset, @import, single-quoted link) and no host is named in an
# attribute but the site's own and those of the external links below (only as those links, with their rel). The only
# mail link is the guide's contact, and on the site only in the privacy and support pages. A typo stops the release before anything is published.
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
# The external links the site may have: Buy me a coffee, Google's policy for the Limited Use statement, ML Kit's data
# disclosure (the QR scanner on Android) and Cloudflare's privacy policy.
external=(https://buymeacoffee.com/camillobucciarelli https://developers.google.com/terms/api-services-user-data-policy
  https://developers.google.com/ml-kit/android-data-disclosure https://www.cloudflare.com/privacypolicy/)

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
  # Link previews: the Open Graph image, published by release.yml (job site) from tool/brand_icons.sh's output.
  has "$dir/$1" "<meta property=\"og:image\" content=\"https://$site/og.png\">"
  has "$dir/$1" '<meta name="twitter:card" content="summary_large_image">'
  [ -s "$dir/og.png" ] || fail "$dir/og.png: missing or empty (tool/brand_icons.sh)"
}
links() { # <file> <its path on the bucket> [the mail link allowed there]
  local base path url host
  base=$(dirname "$2")
  if grep -nE "<script|<style|<iframe|<object|<embed|[[:space:]]style=|srcset=|@import|(href|src)='" "$1"; then
    fail "$1: loads or links something in a form this check does not read"
  fi
  # Hosts in any attribute (script, inline style and srcset are refused above, so nothing else loads); text may name
  # one, as the Gmail scope does in the privacy policy.
  while read -r host; do
    case $host in
      "$site") ;;
      *)
        # Every attribute naming the host is one of the allowed links to it (two on developers.google.com).
        local allowed=0 links=0 u
        for u in "${external[@]}"; do
          [ "$u" != "${u#https://"$host"/}" ] || continue
          allowed=1
          links=$((links + $(grep -oE "<a( class=\"[a-z]+\")? href=\"$u\" rel=\"noopener noreferrer\"" "$1" | wc -l)))
        done
        [ "$allowed" = 1 ] || fail "$1: names the host $host"
        [ "$allowed" = 0 ] || [ "$(grep -oE '="[^"]*"' "$1" | grep -c "//$host" || true)" = "$links" ] ||
          fail "$1: $host other than as an allowed link with rel=\"noopener noreferrer\""
        ;;
    esac
  done < <(grep -oE '="[^"]*"' "$1" | grep -oE '//[A-Za-z0-9.-]+' | sed 's|^//||' | sort -u)
  while read -r url; do
    case $url in
      https://buymeacoffee.com/camillobucciarelli | https://developers.google.com/terms/api-services-user-data-policy | \
        https://developers.google.com/ml-kit/android-data-disclosure | https://www.cloudflare.com/privacypolicy/) continue ;;
      mailto:*) [ "$url" = "${3:-}" ] || fail "$1: mail link $url"; continue ;;
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
page support.html it en en/support.html ''
page en/support.html en it ../support.html ../
product index.html ''
product en/index.html ../
has "$dir/privacy.html" 'href="index.html"'
has "$dir/en/privacy.html" 'href="index.html"'
# Every page links the support page, which carries the privacy contact (#324).
for f in index.html en/index.html privacy.html en/privacy.html; do has "$dir/$f" 'href="support.html"'; done
# The privacy contact is the address the guide already publishes, and only that.
contact=$(grep -oE 'mailto:[^"]+' "$guide" | sort -u || true)
[ "$(printf '%s\n' "$contact" | grep -c .)" = 1 ] || fail "$guide: not exactly one mail address: $contact"
for f in index.html en/index.html; do links "$dir/$f" "$f"; done
for f in privacy.html en/privacy.html support.html en/support.html; do
  links "$dir/$f" "$f" "$contact"
  has "$dir/$f" "<a href=\"$contact\">${contact#mailto:}</a>"
done
for f in privacy.html en/privacy.html; do
  has "$dir/$f" 'href="https://developers.google.com/terms/api-services-user-data-policy" rel="noopener noreferrer"'
done
links "$guide" guida/index.html "$contact"
has "$guide" '<link rel="stylesheet" href="../style.css">'
# Published as they are: a placeholder there would show.
for f in "$dir/privacy.html" "$dir/en/privacy.html" "$dir/support.html" "$dir/en/support.html" "$dir/style.css" "$guide"; do
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
