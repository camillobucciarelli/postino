#!/bin/sh
# Benchmark su Android (emulatore o device via adb), un processo per combinazione.
# Uso: ./run_android.sh <cartella-modelli>   (DEVICE=gpu per Vulkan, PLATFORM=etichetta)
# Prerequisito: flutter build apk --release --split-per-abi
set -eu
cd "$(dirname "$0")"
BASE=$1
PKG=dev.postino.spike.llamadart_app
D=/sdcard/Android/data/$PKG/files
MODELS=${MODELS:-eg2-q8_0.gguf eg2-740m.litertlm eg2-270m.litertlm granite-97m-r2-q8_0.gguf e5-small-q8_0.gguf}
J=$(mktemp)
DEV=${DEVICE:-auto}
PLAT=${PLATFORM:-android-emu}
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk >/dev/null
adb shell mkdir -p $D
adb push ../data/emails.json $D/ >/dev/null
for m in $MODELS; do
  adb shell ls $D/$m >/dev/null 2>&1 || adb push "$BASE/$m" $D/ >/dev/null
done
# La cartella creata da adb è di `shell`: l'app non la legge. Serve un emulatore/device con `adb root`.
APPUID=$(adb shell pm list packages -U $PKG | sed 's/.*uid://' | tr -d '\r')
adb root >/dev/null; adb wait-for-device
adb shell chown -R "$APPUID:1078" /data/media/0/Android/data/$PKG
for m in $MODELS; do
  for t in 256 512; do
    printf '{"MODEL":"%s","MAXTOK":"%s","DEVICE":"%s","PLATFORM":"%s"}' $m $t $DEV $PLAT > "$J"
    adb push "$J" $D/job.json >/dev/null
    adb shell chown "$APPUID:1078" /data/media/0/Android/data/$PKG/files/job.json
    adb logcat -c
    adb shell am start -W -n $PKG/.MainActivity >/dev/null
    while adb shell pidof $PKG >/dev/null 2>&1; do sleep 2; done
    adb logcat -d | grep '\[spike103\]' | sed 's/.*\[spike103\]/[spike103]/' || true
  done
done
adb shell rm -f $D/job.json
mkdir -p ../results/raw ../results/metrics out-android
adb pull $D/out/. out-android/ >/dev/null
mv out-android/*.metrics.json ../results/metrics/ 2>/dev/null || true
mv out-android/*.json ../results/raw/ 2>/dev/null || true
cat out-android/error.txt 2>/dev/null || true
rm -rf out-android
adb shell rm -rf $D/out
