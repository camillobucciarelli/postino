#!/usr/bin/env bash
# Rigenera tutti i PNG di icona, splash e tray, i lockup e l'immagine Open Graph da assets/brand/*.svg (unica fonte,
# vedi docs/brand-icone.md).
# Rasterizza con rsvg-convert se c'è, altrimenti con sips (di serie su macOS, SVG con fondo trasparente).
set -euo pipefail
cd "$(dirname "$0")/.."

command -v sips >/dev/null || { echo "sips non trovato: serve per togliere l'alfa alle icone iOS (macOS)" >&2; exit 1; }

B=assets/brand
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# png <svg> <px> <out>: rasterizza l'SVG (tela quadrata, width/height sulla riga 1) a px x px, fondo trasparente.
png() {
  local src=$1 px=$2 out=$3 name
  name=$(basename "$out" .png)
  sed -E "1s/width=\"[0-9.]+\" height=\"[0-9.]+\"/width=\"$px\" height=\"$px\"/" "$src" > "$T/$name.svg"
  raster "$T/$name.svg" "$out"
}

# raster <svg> <out>: rasterizza l'SVG alla sua misura (width/height sulla riga 1).
raster() {
  mkdir -p "$(dirname "$2")"
  if command -v rsvg-convert >/dev/null; then
    rsvg-convert "$1" -o "$2"
  else
    sips -s format png "$1" --out "$2" >/dev/null
  fi
}

# opaque <png>: toglie il canale alfa (App Store); il tile è a tutto campo, quindi nessuna perdita visibile.
opaque() {
  sips -s format jpeg -s formatOptions 100 "$1" --out "$T/o.jpg" >/dev/null
  sips -s format png "$T/o.jpg" --out "$1" >/dev/null
}

# pick <px>: sotto i 64 px la posa semplificata (righe più spesse), come sulla board.
pick() { if [ "$1" -lt 64 ]; then echo "$B/icon-small.svg"; else echo "$B/icon.svg"; fi; }

# nested <svg> <x> <y> <size> <canvas> <px> <out>: l'SVG (viewBox 256) a (x,y,size) in una tela canvas x canvas.
nested() {
  { printf '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 %s %s"><svg x="%s" y="%s" width="%s" height="%s" viewBox="0 0 256 256">\n' "$5" "$5" "$5" "$5" "$2" "$3" "$4" "$4"
    sed '1d;$d' "$1"
    echo '</svg></svg>'; } > "$T/nested.svg"
  png "$T/nested.svg" "$6" "$7"
}

# iOS: 1024 senza alfa, quadrato a tutto campo (la maschera la mette iOS).
IOS=ios/Runner/Assets.xcassets/AppIcon.appiconset
for v in "icon:AppIcon" "icon-dark:AppIcon-dark" "icon-tinted:AppIcon-tinted"; do
  sed 's/ rx="57"//' "$B/${v%%:*}.svg" > "$T/square.svg"
  png "$T/square.svg" 1024 "$IOS/${v##*:}.png"
  opaque "$IOS/${v##*:}.png"
done

# macOS: tile 824/1024 al centro (griglia Big Sur), margine trasparente; rx 57/256 è già la squircle di macOS.
for px in 16 32 64 128 256 512 1024; do
  nested "$(pick "$px")" 100 100 824 1024 "$px" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$px.png"
done
# Android: legacy (< API 26), foreground adattivo (marchio al 30% nella zona sicura 66/108 dp), monochrome, splash.
RES=android/app/src/main/res
for d in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  n=${d%%:*}; k=${d##*:}
  px=$(awk "BEGIN{print 48*$k}"); fg=$(awk "BEGIN{print 108*$k}"); sp=$(awk "BEGIN{print 128*$k}")
  png "$(pick "$px")" "$px" "$RES/mipmap-$n/ic_launcher.png"
  nested "$B/mark.svg" 15.6 15 76.8 108 "$fg" "$RES/mipmap-$n/ic_launcher_foreground.png"
  nested "$B/mark-mono.svg" 15.6 15 76.8 108 "$fg" "$RES/mipmap-$n/ic_launcher_monochrome.png"
  png "$B/mark.svg" "$sp" "$RES/drawable-$n/splash_mark.png"
done

# iOS splash: marchio 128 pt a 1x/2x/3x.
LI=ios/Runner/Assets.xcassets/LaunchImage.imageset
png "$B/mark.svg" 128 "$LI/LaunchImage.png"
png "$B/mark.svg" 256 "$LI/LaunchImage@2x.png"
png "$B/mark.svg" 384 "$LI/LaunchImage@3x.png"
# Tray desktop: macOS template (silhouette nera con alfa, 36 px = 18 pt @2x, la barra dei menu la colora);
# Windows e Linux a colori, 64 px (il sistema scala alla misura del tray).
png "$B/mark-mono.svg" 36 assets/tray/tray_icon_template.png
png "$B/icon.svg" 64 assets/tray/tray_icon.png

# Lockup: marchio + «Postino» (wordmark.svg, Caprasimo in tracciati). Unità: il marchio è alto 152 (busta 56..208
# di mark.svg), area di rispetto 76 = metà tutt'intorno, 40 tra marchio e scritta, maiuscole alte 96 centrate sul
# marchio. lockup.svg per fondi chiari (tile + inchiostro), lockup-dark.svg per fondi scuri o verderame (marchio + carta).
# inline <svg> <viewBox> <x> <y> <w> <h>: il contenuto dell'SVG (righe 2..penultima) in un <svg> annidato.
inline() {
  printf '<svg x="%s" y="%s" width="%s" height="%s" viewBox="%s">\n' "$3" "$4" "$5" "$6" "$2"
  sed '1d;$d' "$1"
  echo '</svg>'
}
lockup() { # <marchio svg> <viewBox marchio> <larghezza marchio> <colore scritta> <out>
  local x=$((76 + $3 + 40))
  local w=$(awk "BEGIN{print $x + 518.97 + 76}")
  { printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %s 304" width="%s" height="304">\n' "$w" "$w"
    inline "$1" "$2" 76 76 "$3" 152
    printf '<g fill="%s">\n' "$4"
    inline "$B/wordmark.svg" "39 -1462 7752 1493" "$x" 102.13 518.97 99.95
    echo '</g>'
    echo '</svg>'; } > "$5"
}
lockup "$B/icon.svg" "0 0 256 256" 152 "#1c1c1a" "$B/lockup.svg"
lockup "$B/mark.svg" "40 56 176 152" 176 "#fffdf8" "$B/lockup-dark.svg"

# Open Graph del sito: 1200x630, fondo verderame del tile, lockup chiaro centrato (largo 960), senza alfa.
{ echo '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 630" width="1200" height="630">'
  sed -n 2p "$B/icon.svg"
  echo '<rect width="1200" height="630" fill="url(#t)"/>'
  inline "$B/lockup-dark.svg" "0 0 886.97 304" 120 150.4 960 329.08
  echo '</svg>'; } > "$T/og.svg"
raster "$T/og.svg" docs/download/og.png
opaque docs/download/og.png
echo "Icone e splash rigenerate da $B"
