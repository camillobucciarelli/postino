#!/bin/bash
# Self-check of download_check.sh, run by ci.yml: the real site passes, and each kind of slip fails: something loaded
# from a third party (link, script, inline style, srcset, single-quoted attribute, @import, a Buy me a coffee widget),
# a link to a missing file (relative or absolute on the site's host), Buy me a coffee, Google's policy or ML Kit's
# disclosure without their rel (while a page without the ML Kit link passes), another page of an allowed host, a mail link other than the guide's privacy contact, wrong
# lang, missing switch to the twin, lost download or footer link, missing font or license, lost Open Graph meta or
# a missing or empty og.png, a placeholder on a page
# published as it is, broken markup, and the same slips in the guide. Since #364: a #fragment with no such id (on this
# page, another page or the guide), an empty one or one on a file that is not a page, an <img> without alt or size, a
# file in img/ or icone/ of a type release.yml does not upload, an icon that loads or runs something, an HTML5 tag the
# check does not know, an <img> wrapped over two lines without alt; while a fragment to an existing id (also of the
# guide), a decorative image, another PNG, another clean icon and the known HTML5 tags pass.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
site=docs/download
guide=docs/guida-invitati/index.html

tool/release/download_check.sh "$site" "$guide" > /dev/null || { echo "the real site should pass"; exit 1; }
fails() { # <what> <file in the site, or "guide"> <sed on it, "rm", or "cp:<site file>" to add it as a copy of that>
  rm -rf "$tmp/s"
  cp -R "$site" "$tmp/s"
  cp "$guide" "$tmp/guide.html"
  local target="$tmp/s/$2" source="$site/$2"
  if [ "$2" = guide ]; then target="$tmp/guide.html"; source=$guide; fi
  if [ "$3" = rm ]; then rm "$target"; elif [ "${3#cp:}" != "$3" ]; then cp "$site/${3#cp:}" "$target"; else
    sed -E "$3" "$source" > "$target"
    if cmp -s "$source" "$target"; then echo "the sed of '$1' changed nothing"; exit 1; fi
  fi
  if tool/release/download_check.sh "$tmp/s" "$tmp/guide.html" > /dev/null 2>&1; then echo "should fail: $1"; exit 1; fi
}
passes() { # <what> <file in the site> <sed on it, or "cp:<site file>" to add it as a copy of that> [sed on the guide]
  rm -rf "$tmp/s"
  cp -R "$site" "$tmp/s"
  sed -E "${4:-}" "$guide" > "$tmp/guide.html"
  if [ "${3#cp:}" != "$3" ]; then cp "$site/${3#cp:}" "$tmp/s/$2"; else
    sed -E "$3" "$site/$2" > "$tmp/s/$2"
    if cmp -s "$site/$2" "$tmp/s/$2"; then echo "the sed of '$1' changed nothing"; exit 1; fi
  fi
  tool/release/download_check.sh "$tmp/s" "$tmp/guide.html" > /dev/null || { echo "should pass: $1"; exit 1; }
}
# Two allowed links on developers.google.com: a page without the ML Kit one is still fine.
passes "only the policy of the two Google links" privacy.html 's|<a href="https://developers.google.com/ml-kit/android-data-disclosure"[^>]*>([^<]*)</a>|\1|'
fails "Google Fonts link" index.html 's|</head>|<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Figtree"></head>|'
fails "third-party script" en/privacy.html 's|</body>|<script src="https://example.com/a.js"></script></body>|'
fails "Buy me a coffee widget" en/index.html 's|</body>|<script src="https://buymeacoffee.com/widget.js"></script></body>|'
fails "inline style" privacy.html 's|</head>|<style>body{background:red}</style></head>|'
fails "style attribute" index.html 's|<main id="contenuto">|<main id="contenuto" style="color:red">|'
fails "srcset" index.html 's|<img class="telefono"|<img srcset="https://cdn.example/l.png 2x" class="telefono"|'
fails "single-quoted link" index.html "s|</head>|<link rel='stylesheet' href='https://fonts.gstatic.com/x.css'></head>|"
fails "url() in the stylesheet" sito.css '1s|^|body { background: url(https://tracker.example/p.gif); }|'
fails "bare @import in the stylesheet" sito.css '1s|^|@import "fonts.css";|'
fails "missing font file" fonts/figtree-latin.woff2 rm
fails "missing license" fonts/caprasimo-OFL.txt rm
fails "link to a missing file" index.html 's|src="brand/icon.svg"|src="brand/logo.svg"|'
fails "absolute link to a missing file" en/index.html 's|<footer class="piede">|<footer class="piede"><a href="https://postino.camillobucciarelli.dev/nope.html">x</a>|'
fails "Buy me a coffee pill without rel" privacy.html 's| rel="noopener noreferrer"><span| rel="noopener"><span|'
fails "support link without rel" index.html 's| rel="noopener noreferrer">Offrimi|>Offrimi|'
fails "Buy me a coffee pill gone" en/index.html 's|class="sponsor" ||'
fails "lang" en/index.html 's|<html lang="en">|<html lang="it">|'
fails "switch to the twin" en/privacy.html 's|href="../privacy.html" hreflang="it"|href="../index.html" hreflang="it"|'
fails "download link" en/index.html 's|\.\./android/latest/Postino.apk|android/latest/Postino.apk|'
fails "privacy link of the product page" en/index.html 's|<a href="privacy.html">|<a href="../privacy.html">|'
fails "back link of the privacy page" privacy.html 's|href="index.html"|href="en/index.html"|g'
fails "placeholder on a page published as it is" privacy.html 's|Ultimo aggiornamento|__VERSION__|'
fails "broken markup" privacy.html 's|</ul>|</strong></ul>|'
fails "policy link without rel" en/privacy.html 's|policy" rel="noopener noreferrer">|policy">|'
fails "policy URL on a link element" en/privacy.html 's|</head>|<link href="https://developers.google.com/terms/api-services-user-data-policy" rel="noopener noreferrer"></head>|'
fails "ML Kit link without rel" privacy.html 's|android-data-disclosure" rel="noopener noreferrer"|android-data-disclosure"|'
fails "policy without rel beside ML Kit" privacy.html 's|policy" rel="noopener noreferrer"|policy"|'
fails "other page of the policy host" privacy.html 's|api-services-user-data-policy"|other-page"|'
fails "Cloudflare policy without rel" privacy.html 's|privacypolicy/" rel="noopener noreferrer"|privacypolicy/"|'
fails "other page of Cloudflare" en/privacy.html 's|cloudflare.com/privacypolicy/|cloudflare.com/other/|'
fails "privacy contact other than the guide's" privacy.html 's|mailto:camillo@bucciarelli.dev|mailto:privacy@example.com|'
fails "privacy contact gone" en/privacy.html 's|<a href="mailto:[^"]*">([^<]*)</a>|\1|'
fails "mail link on the product page" index.html 's|<footer class="piede">|<footer class="piede"><a href="mailto:camillo@bucciarelli.dev">x</a>|'
fails "support page gone" support.html rm
fails "twin support page gone" en/support.html rm
fails "support link gone from the product page" index.html 's|href="support.html"|href="privacy.html"|'
fails "support link gone from the privacy page" en/privacy.html 's|href="support.html"|href="privacy.html"|'
fails "support contact other than the guide's" support.html 's|mailto:camillo@bucciarelli.dev|mailto:support@example.com|'
fails "placeholder on a support page" en/support.html 's|<main id="contenuto" class="articolo">|&__VERSION__|'
fails "Open Graph image meta gone" index.html 's|<meta property="og:image" [^>]*>||'
fails "Twitter card meta gone" en/index.html 's|<meta name="twitter:card" [^>]*>||'
fails "missing Open Graph image" og.png rm
fails "empty Open Graph image" og.png d
passes "a link to an id of another page" index.html 's|<li><a href="privacy.html">Informativa|<li><a href="privacy.html#eliminare-i-dati">Informativa|'
fails "a link to a missing id of this page" index.html 's|<a class="pulsante" href="#scarica">Scarica</a>|<a class="pulsante" href="#scaricare">Scarica</a>|'
fails "a link to a missing id of another page" en/support.html 's|index.html#funzioni|index.html#features|'
fails "a link to a missing id of the guide" index.html 's|<li><a href="guida/index.html">Guida</a>|<li><a href="guida/index.html#macos">Guida</a>|'
fails "an empty fragment" privacy.html 's|<a class="marchio" href="index.html">|<a class="marchio" href="#">|'
fails "a fragment on a file that is not a page" support.html 's|src="brand/icon.svg"|src="brand/icon.svg#x"|'
passes "a decorative image" index.html 's|alt="Ricerca su iPhone: da:marta e tre risultati"|alt=""|'
fails "an image without alt" index.html 's| alt="Ricerca su iPhone: da:marta e tre risultati"||'
fails "an image without size" en/index.html 's| width="560" height="1217"||'
fails "a wrapped image without alt" index.html $'s|<img class="telefono" src="img/iphone-ricerca.png" width="560" height="1217" alt="[^"]*">|<img\\\n  class="telefono" src="img/iphone-ricerca.png" width="560" height="1217">|'
passes "another PNG in img" img/altra.png cp:img/iphone-ricerca.png
fails "a JPEG in img" img/foto.jpg cp:img/iphone-ricerca.png
fails "a PNG in icone" icone/icona.png cp:img/iphone-ricerca.png
fails "an icon that loads an image" icone/lock.svg 's|</svg>|<image href="https://tracker.example/p.png"/></svg>|'
fails "an icon with an event handler" icone/check.svg 's|<svg |<svg onload="alert(1)" |'
fails "a missing icon" icone/lock.svg rm
passes "another clean icon" icone/nuova.svg cp:icone/check.svg
fails "an HTML5 tag the check does not know" support.html 's|</main>|<aside>x</aside></main>|'
passes "the HTML5 tags the check knows" support.html 's|</main>|<section><nav><header>x</header></nav></section></main>|'
passes "a link to an id of the guide" index.html 's|<li><a href="guida/index.html">Guida</a>|<li><a href="guida/index.html#macos">Guida</a>|' 's|<h2>macOS</h2>|<h2 id="macos">macOS</h2>|'
fails "guide without its mail address" guide 's|<a href="mailto:[^"]*">([^<]*)</a>|\1|g; s|mailto:||g'
fails "guide with a third-party font" guide 's|</head>|<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Figtree"></head>|'
fails "guide with a missing stylesheet" guide 's|href="../sito.css"|href="../stile.css"|'
echo "download_check.sh ok"
