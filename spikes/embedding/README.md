# Spike #103 — embedding on-device per l'Etichettatura automatica

Codice usa e getta, non entra in `lib/`. Confronta runtime e modelli di embedding sulla classificazione delle email
nelle Etichette dell'utente: zero-shot (email contro nome + descrizione dell'Etichetta) e kNN sugli esempi etichettati.

## Struttura

- `data/emails.json` — dataset sintetico: 8 Etichette (`name`, `description`) e 80 email (10 per Etichetta, 40 IT e
  40 EN) con `id`, `label`, `lang`, `from`, `subject`, `body`. Lunghezze miste (16 email oltre 450 parole, per far
  contare il troncamento 256 vs 512 token) e qualche caso ambiguo (ordine con fattura, trasferta di lavoro, promo
  di una compagnia aerea, avvisi di sicurezza della banca). Le latenze si misurano sulle stesse email.
- `eval/` — package Dart puro (senza Flutter) che calcola le metriche dai JSON prodotti dai prototipi.

## Testo da embeddare

I prototipi devono embeddare esattamente questi testi (`eval/lib/embedding_text.dart`):

- email: `"Oggetto: <subject>\nDa: <from>\n\n<body>"`, troncato a 256 o 512 token dal prototipo con il tokenizer del
  modello;
- Etichetta: `"<name>: <description>"`.

Eventuali prefissi di task richiesti dal modello (es. `query: ` per multilingual-e5) li aggiunge il prototipo e li
indica nel campo `model`.

## Formato di scambio

Ogni prototipo scrive un file JSON per combinazione runtime/modello/troncamento:

```json
{
  "runtime": "llamadart",
  "model": "embeddinggemma-q8_0",
  "maxTokens": 512,
  "labels": [{ "name": "Viaggi", "embedding": [0.01, -0.2] }],
  "emails": [{ "id": "via-it-01", "label": "Viaggi", "lang": "it", "embedding": [0.03, 0.11] }]
}
```

## Valutatore

```sh
cd spikes/embedding/eval
dart pub get
dart run bin/eval.dart ../results/llamadart-gemma-512.json [altri.json ...]
dart test
```

Stampa una riga di tabella markdown per file e scrive `<file>.eval.json` accanto a ogni input. Metriche:

- zero-shot: Etichetta con coseno massimo;
- kNN leave-one-out (k = 3 e 5, voto pesato per coseno) e centroide leave-one-out: l'email non vede sé stessa;
- tutte le accuratezze anche separate per IT ed EN;
- zero-shot con astensione: copertura e precisione quando la top-1 supera la seconda di almeno 0, 0.02, 0.05.

## Prototipo flutter_edge_ai (`edge_ai_app/`)

flutter_edge_ai 2.5.5 + flutter_edge_ai_litertlm 1.19.1 con EmbeddingGemma 2 `.litertlm`. Risultati in
`results/edge_ai.md`. L'app è headless: all'avvio installa il modello con `modelFromFile`, esegue maxTokens 256 e
512, scrive `edge_ai-<piattaforma>-<modello>-<maxTok>.json` (formato di scambio) e `.metrics.json`, poi termina.
I tagli di troncamento sono in `assets/token_cuts.json` (rigenerarli con `tool/token_cuts.py` se cambia il dataset).

```sh
M=/percorso/modelli   # embeddinggemma-2-text-270m.litertlm e/o embeddinggemma-2-740m.litertlm da
                      # huggingface.co/litert-community/embeddinggemma-2-{text-270m,740m}-litert-lm
cd spikes/embedding/edge_ai_app
# macOS: modello e uscita da variabili d'ambiente (sandbox disattivata per lo spike)
flutter build macos --release
EDGE_MODEL=embeddinggemma-2-text-270m EDGE_MODEL_DIR=$M EDGE_OUT_DIR=$PWD/../results/raw \
  build/macos/Build/Products/Release/edge_ai_app.app/Contents/MacOS/edge_ai_app
# simulatore iOS (solo debug): il modello va nei Documents dell'app
flutter build ios --simulator --debug
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
D=$(xcrun simctl get_app_container booted dev.postino.spike.edgeAiApp data)/Documents
mkdir -p $D && cp $M/embeddinggemma-2-text-270m.litertlm $D/
xcrun simctl launch --console-pty booted dev.postino.spike.edgeAiApp && cp $D/edge_ai-*.json ../results/raw/
# emulatore/telefono Android (arm64, API ≥ 30): il modello va nella cartella esterna dell'app
flutter build apk --release --split-per-abi --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
P=/sdcard/Android/data/dev.postino.spike.edge_ai_app/files
adb shell mkdir -p $P && adb push $M/embeddinggemma-2-text-270m.litertlm $P/
adb shell am start -n dev.postino.spike.edge_ai_app/.MainActivity   # attendere che il processo termini
for f in $(adb shell ls $P | grep '^edge_ai-.*json'); do adb pull $P/$f ../results/raw/; done
cd ../eval && dart run bin/eval.dart ../results/raw/edge_ai-*-256.json ../results/raw/edge_ai-*-512.json
```

Su mobile il 740m si sceglie con `--dart-define=MODEL=embeddinggemma-2-740m` in build. Gli embedding grezzi
(`results/raw/*.json`) non si committano; metriche ed `.eval.json` sì.
