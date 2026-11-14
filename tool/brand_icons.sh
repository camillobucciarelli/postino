#!/usr/bin/env bash
# Rigenera tutti i PNG di icona e splash da assets/brand/*.svg (unica fonte, vedi docs/brand-icone.md).
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
  mkdir -p "$(dirname "$out")"
  if command -v rsvg-convert >/dev/null; then
    rsvg-convert -w "$px" -h "$px" "$T/$name.svg" -o "$out"
  else
    sips -s format png "$T/$name.svg" --out "$out" >/dev/null
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
  png "$B/mark-closed.svg" "$sp" "$RES/drawable-$n/splash_mark.png"
  # Android 12+: icona animata dello splash, tela 288 dp mascherata a cerchio di 192 dp: busta chiusa 128 dp al centro.
  nested "$B/mark-closed.svg" 80 80 128 288 "$(awk "BEGIN{print 288*$k}")" "$RES/drawable-$n/splash_icon.png"
done

# iOS splash: busta chiusa (posa a 0 ms dell'animazione, #267) 128 pt a 1x/2x/3x.
LI=ios/Runner/Assets.xcassets/LaunchImage.imageset
png "$B/mark-closed.svg" 128 "$LI/LaunchImage.png"
png "$B/mark-closed.svg" 256 "$LI/LaunchImage@2x.png"
png "$B/mark-closed.svg" 384 "$LI/LaunchImage@3x.png"
# Tray desktop: macOS template (silhouette nera con alfa, 36 px = 18 pt @2x, la barra dei menu la colora);
# Windows e Linux a colori, 64 px (il sistema scala alla misura del tray).
png "$B/mark-mono.svg" 36 assets/tray/tray_icon_template.png
png "$B/icon.svg" 64 assets/tray/tray_icon.png
echo "Icone e splash rigenerate da $B"
