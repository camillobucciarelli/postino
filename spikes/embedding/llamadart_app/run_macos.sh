#!/bin/sh
# Esegue il benchmark su macOS, un processo per combinazione (RSS pulito).
# Uso: ./run_macos.sh <cartella-modelli> [file-modello...]
# Prerequisito: flutter build macos --release
set -eu
cd "$(dirname "$0")"
BASE=$1; shift
MODELS=${*:-eg2-q8_0.gguf eg2-bf16.gguf eg2-740m.litertlm eg2-270m.litertlm granite-97m-r2-q8_0.gguf e5-small-q8_0.gguf}
BIN=build/macos/Build/Products/Release/llamadart_app.app/Contents/MacOS/llamadart_app
OUT=../results/raw
mkdir -p "$OUT" ../results/metrics
for m in $MODELS; do
  for t in 256 512; do
    [ -f "$BASE/$m" ] || { echo "manca $BASE/$m"; continue; }
    BASE=$BASE DATA=$PWD/../data/emails.json MODEL=$m MAXTOK=$t PLATFORM=macos DEVICE=${DEVICE:-auto} \
      "$BIN" 2>&1 | grep '\[spike103\]' || true
  done
done
mv "$BASE"/out/*.metrics.json ../results/metrics/ 2>/dev/null || true
mv "$BASE"/out/*.json "$OUT"/ 2>/dev/null || true
