# Spike #103 — flutter_edge_ai + EmbeddingGemma 2 (.litertlm)

flutter_edge_ai 2.5.5 + flutter_edge_ai_litertlm 1.19.1, Flutter 3.47.8, app `edge_ai_app/`, 2026-11-04. Embedding
su CPU (XNNPack; l'embedding engine LiteRT è solo CPU), 768 dim, `TaskType.classification` (prefisso
`task: classification | query: `) per email ed Etichette. Accuratezze dal valutatore (`*.eval.json`), metriche grezze
in `raw/edge_ai-*.metrics.json`.

| piattaforma | modello | maxTok | dim | load ms | p50/p95 ms per email | RSS dopo load / max MB | zero-shot | kNN5 | centroide |
|---|---|---|---|---|---|---|---|---|---|
| macOS (M5 Pro) | EG2 text 270m | 256 | 768 | 514 | 61 / 93 | 272 / 593 | 0.82 | 0.84 | 0.88 |
| macOS (M5 Pro) | EG2 text 270m | 512 | 768 | 155* | 57 / 116 | 243 / 630 | 0.82 | 0.86 | 0.91 |
| macOS (M5 Pro) | EG2 740m | 256 | 768 | 2201† | 72 / 177 | 679 / 998 | 0.82 | 0.84 | 0.88 |
| macOS (M5 Pro) | EG2 740m | 512 | 768 | 228* | 72 / 279 | 295 / 998 | 0.82 | 0.86 | 0.91 |
| simulatore iOS 26.5 (iPhone 17 Pro, debug) | EG2 text 270m | 256 | 768 | 929† | 87 / 201 | 460 / 664 | 0.82 | 0.84 | 0.88 |
| simulatore iOS 26.5 (iPhone 17 Pro, debug) | EG2 text 270m | 512 | 768 | 364* | 70 / 155 | 265 / 664 | 0.82 | 0.86 | 0.91 |
| emulatore Android 16 (API 36 arm64, 4 core, 4 GB) | EG2 text 270m | 256 | 768 | 9448† | 138 / 307 | 362 / 823 | 0.82 | 0.84 | 0.88 |
| emulatore Android 16 (API 36 arm64, 4 core, 4 GB) | EG2 text 270m | 512 | 768 | 1164* | 154 / 526 | 384 / 823 | 0.82 | 0.86 | 0.91 |

\* secondo load nello stesso processo (dopo `close()` del 256), cache dei pesi XNNPack calda.
† primo load con cache XNNPack da costruire (per il 740m su macOS la cache del 270m c'era già, quella del 740m no).
Il load macOS 270m a 256 (514 ms) è il primo load di un processo nuovo con cache già calda.
RSS: `ProcessInfo.currentRss` prima/dopo il load; il max è `ProcessInfo.maxRss` del processo, quindi a 512 include
il run a 256 e la parte di `createDecider`. RSS prima del load (processo Flutter vuoto): 120 MB macOS, 184 MB Android,
373 MB simulatore iOS (debug/JIT).

- **740m = 270m per il testo**: i vettori sono identici (coseno 1.000000 sulla stessa email) e le accuratezze pure;
  il 740m aggiunge solo le torri immagine/audio: +320 MB di file, +400 MB di RSS, latenza p95 più alta.
- **Simulatore ed emulatore non rappresentano un telefono**: il simulatore gira sulla CPU del Mac, in debug (il
  simulatore non ha la modalità release); l'emulatore è arm64 su Apple Silicon. Le accuratezze sono identiche su
  tutte le piattaforme (gli stessi vettori a meno di arrotondamenti).
- **createDecider** (`DeciderMethod.centroid`, `EmbeddingDeciderCalibration.none()`, opzioni = `labelText` delle 8
  Etichette, prefisso fisso `sentenceSimilarity`): 0.85 (IT 0.875 / EN 0.825) a 256 e 512, su ogni piattaforma e
  modello, contro 0.82 dello zero-shot coseno con prefisso classification. API sperimentale (`@experimental`).

## Troncamento

flutter_edge_ai non espone il tokenizer del `.litertlm`, non tronca mai (input > 1024 token →
`EmbeddingInputTooLongException`) e riporta il conteggio solo nell'eccezione. I tagli sono quindi calcolati
offline da `edge_ai_app/tool/token_cuts.py` con il `tokenizer.json` ufficiale di `google/embeddinggemma-2`:
per ogni email il numero di code point di `emailText` da tenere perché `<bos>` + prefisso + testo + `<eos>` stia in
maxTokens (prefisso, BOS ed EOS contati). Risultato in `edge_ai_app/assets/token_cuts.json`: 18/80 email troncate a
256, 17/80 a 512; token per email (prefisso incluso) min 65, mediana 144, max 873. Controllo nell'app: l'email più
lunga ripetuta due volte fa 1739 token sia per lo script sia per il motore (conteggio esatto dell'eccezione), su
tutte le piattaforme.

## Peso aggiunto (release, modello escluso)

| piattaforma | app vuota | edge_ai_app | differenza |
|---|---|---|---|
| macOS `.app` (universal; LiteRT solo arm64) | 36.9 MB | 88.9 MB | +52.0 MB |
| iOS `Runner.app` (`--no-codesign`) | 13.9 MB | 53.8 MB | +39.9 MB |
| APK arm64-v8a (`--split-per-abi`) | 15.5 MB | 57.9 MB | +42.4 MB |

MB = 10^6 byte per l'APK, MiB (`du -sk`) per le `.app`. Modelli a parte: 270m 164.6 MB, 740m 484.6 MB; cache dei
pesi XNNPack nella cache dell'app: 71 MB (270m) / 385 MB (740m) secondo la documentazione del pacchetto.
