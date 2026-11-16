#!/usr/bin/env bash
# Cattura le cinque schermate di Google Play da un emulatore Android: come shots.sh, ma con adb al posto di simctl.
# A ogni riga `SHOT <nome>` di integration_test/store_screenshots_test.dart salva
# docs/store/screenshot/android/<lingua>/<nome>.png con `adb exec-out screencap`, poi toglie l'alfa (opaque.swift).
# Uso: tool/store_screenshots/shots_android.sh <seriale emulator-NNNN> <it|en>
# Prima: server.sh avviato, la sua CA nei certificati di sistema dell'emulatore, lingua dell'emulatore = <lingua>
# (docs/store/screenshot.md). Solo su un emulatore creato apposta: lo script disinstalla Postino, così parte senza Account.
set -euo pipefail
serial=$1 lang=$2
here=$(cd "$(dirname "$0")" && pwd)
cd "$here/../.."
[[ $serial == emulator-* ]] || { echo "$serial non è un emulatore" >&2; exit 1; }
export ANDROID_SERIAL=$serial
out=docs/store/screenshot/android/$lang
rm -rf "$out" && mkdir -p "$out"
adb uninstall com.cbucciarelli.postino >/dev/null 2>&1 || true
# Su Mac M4+ l'OpenSSL di SQLCipher va in SIGILL sull'emulatore rilevando SVE: niente rilevamento, solo per Postino.
adb shell setprop wrap.com.cbucciarelli.postino OPENSSL_armcap=0
# localhost dell'emulatore → localhost del Mac, dove gira GreenMail (il certificato è per localhost).
adb reverse tcp:3993 tcp:3993 && adb reverse tcp:3465 tcp:3465
# Barra di stato pulita con la demo mode di SystemUI: 9:41, batteria piena, Wi-Fi pieno, niente icone di notifica.
demo() { adb shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }
adb shell settings put global sysui_demo_allowed 1
demo enter
demo clock -e hhmm 0941
demo battery -e level 100 -e plugged false
demo network -e wifi show -e level 4 -e fully true
demo network -e mobile hide
demo network -e satellite hide # senza rete cellulare Android 16 mostra l'icona del satellite
demo notifications -e visible false
trap 'demo exit; adb reverse --remove-all' EXIT
fvm flutter test integration_test/store_screenshots_test.dart -d "$serial" --dart-define=STORE_SHOTS="$lang" 2>&1 |
  while IFS= read -r line; do
    echo "$line"
    if [[ $line =~ SHOT\ (0[1-5]-[a-z-]+) ]]; then
      adb exec-out screencap -p > "$out/${BASH_REMATCH[1]}.png"
    fi
  done
shots=("$out"/0[1-5]-*.png)
[ ${#shots[@]} -eq 5 ] || { echo "attese 5 immagini in $out, trovate ${#shots[@]}" >&2; exit 1; }
swift "$here/opaque.swift" "${shots[@]}"
