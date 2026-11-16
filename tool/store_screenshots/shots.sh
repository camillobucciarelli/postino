#!/usr/bin/env bash
# Cattura le cinque schermate dello Store da un simulatore iOS: lancia integration_test/store_screenshots_test.dart
# e a ogni riga `SHOT <nome>` salva docs/store/screenshot/<piattaforma>/<lingua>/<nome>.png con simctl, poi toglie
# il canale alfa (opaque.swift). Esce con errore se il driver fallisce o se manca una delle cinque immagini.
# Uso: tool/store_screenshots/shots.sh <udid> <iphone|ipad> <it|en>
# Prima: server.sh avviato, la sua CA fidata nel simulatore, lingua del simulatore = <lingua>. Solo su un simulatore
# creato apposta: lo script disinstalla Postino da <udid>, così parte senza Account.
set -euo pipefail
udid=$1 platform=$2 lang=$3
here=$(cd "$(dirname "$0")" && pwd)
cd "$here/../.."
xcrun simctl list devices | grep -q "($udid)" || { echo "$udid non è un simulatore" >&2; exit 1; }
out=docs/store/screenshot/$platform/$lang
rm -rf "$out" && mkdir -p "$out"
xcrun simctl uninstall "$udid" com.cbucciarelli.postino
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 --dataNetwork wifi
trap 'xcrun simctl status_bar "$udid" clear' EXIT
fvm flutter test integration_test/store_screenshots_test.dart -d "$udid" --dart-define=STORE_SHOTS="$lang" 2>&1 |
  while IFS= read -r line; do
    echo "$line"
    if [[ $line =~ SHOT\ (0[1-5]-[a-z-]+) ]]; then
      xcrun simctl io "$udid" screenshot "$out/${BASH_REMATCH[1]}.png" >/dev/null 2>&1
    fi
  done
shots=("$out"/0[1-5]-*.png)
[ ${#shots[@]} -eq 5 ] || { echo "attese 5 immagini in $out, trovate ${#shots[@]}" >&2; exit 1; }
swift "$here/opaque.swift" "${shots[@]}"
