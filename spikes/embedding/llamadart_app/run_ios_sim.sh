#!/bin/sh
# Benchmark sul simulatore iOS (solo CPU, non rappresentativo), un processo per combinazione.
# Uso: ./run_ios_sim.sh <udid> <cartella-modelli>
# Prerequisito: flutter build ios --simulator --debug (il simulatore non supporta release).
set -eu
cd "$(dirname "$0")"
U=$1; BASE=$2
BID=dev.postino.spike.llamadartApp
MODELS=${MODELS:-eg2-q8_0.gguf eg2-740m.litertlm eg2-270m.litertlm granite-97m-r2-q8_0.gguf e5-small-q8_0.gguf}
xcrun simctl install "$U" build/ios/iphonesimulator/Runner.app
C=$(xcrun simctl get_app_container "$U" $BID data)/Documents
mkdir -p "$C"
cp ../data/emails.json "$C"/
for m in $MODELS; do cp -c "$BASE/$m" "$C"/ 2>/dev/null || cp "$BASE/$m" "$C"/; done
for m in $MODELS; do
  for t in 256 512; do
    # L'app iOS non vede le variabili d'ambiente: la combinazione passa da job.json.
    printf '{"MODEL":"%s","MAXTOK":"%s","PLATFORM":"ios-sim"}' $m $t > "$C/job.json"
    xcrun simctl launch "$U" $BID >/dev/null
    # launch non attende l'uscita: aspetta che il processo dell'app sparisca (i print vanno in os_log).
    sleep 2
    while xcrun simctl spawn "$U" launchctl list | grep "UIKitApplication:$BID" | grep -qv '^-'; do sleep 2; done
    echo "fatto $m $t"; ls "$C"/out 2>/dev/null | grep -c metrics || true
  done
done
rm -f "$C/job.json"
mkdir -p ../results/raw ../results/metrics
mv "$C"/out/*.metrics.json ../results/metrics/ 2>/dev/null || true
mv "$C"/out/*.json ../results/raw/ 2>/dev/null || true
