# Spike #103 — risultati llamadart 0.17.5

Misure del 2026-11-04 con `llamadart_app/` (vedi README). Mac: Apple M5 Pro 18 core, 24 GB, macOS 27.2.
Simulatore iOS: iPhone 17 Pro iOS 26.5, build debug (il simulatore non ha release), solo CPU. Emulatore Android:
AVD `spike36` API 36 arm64, 4 GB, release, CPU. Simulatore ed emulatore girano sulla CPU del Mac: le latenze mobili
**non** sono rappresentative di un telefono, servono device fisici. Durante le misure macOS erano accesi anche
emulatore e simulatore e un altro prototipo misurava a turni (lock): la varianza tra run ripetuti è ±30-50% sulle
latenze Metal di EG2.

Colonne: `load` = `LlamaEngine.load`; `1° embed` = primo embed di warmup (per LiteRT-LM include il caricamento vero,
che è pigro); p50/p95 sulle 80 email una alla volta dopo 3 di warmup; RSS da `ProcessInfo` (MB). `dim 256` = stessi
vettori EG2 troncati a 256 e rinormalizzati (Matryoshka, come `LlamaTextEmbedder(dimensions: 256)`). `512 (511)`:
e5 GGUF dichiara `context_length` 511, oltre llama.cpp va in `GGML_ASSERT` e chiude il processo, quindi tronca a 511.
Accuratezze su 80 email (zero-shot, kNN5 e centroide leave-one-out).

| piattaforma | modello | backend | maxTok | dim | load / 1° embed ms | p50 / p95 ms per email | RSS dopo load / max MB | zero-shot | kNN5 | centroide |
|---|---|---|---|---|---|---|---|---|---|---|
| android-emu | e5-small-q8_0 | CPU | 256 | 384 | 961 / 29 | 23 / 52 | 442 / 453 | 0.65 | 0.71 | 0.80 |
| android-emu | e5-small-q8_0 | CPU | 512 (511) | 384 | 748 / 63 | 23 / 119 | 442 / 462 | 0.69 | 0.70 | 0.84 |
| android-emu | eg2-270m-litertlm | LiteRT-LM cpu | 256 | 768 | 10 / 2331 | 101 / 152 | 173 / 612 | 0.84 | 0.82 | 0.88 |
| android-emu | eg2-270m-litertlm | LiteRT-LM cpu | 256 | 256 | 10 / 2331 | 101 / 152 | 173 / 612 | 0.84 | 0.80 | 0.89 |
| android-emu | eg2-270m-litertlm | LiteRT-LM cpu | 512 | 768 | 18 / 8459 | 281 / 942 | 174 / 664 | 0.84 | 0.85 | 0.93 |
| android-emu | eg2-270m-litertlm | LiteRT-LM cpu | 512 | 256 | 18 / 8459 | 281 / 942 | 174 / 664 | 0.82 | 0.82 | 0.93 |
| android-emu | eg2-740m-litertlm | LiteRT-LM cpu | 256 | 768 | 9 / 10527 | 94 / 230 | 173 / 707 | 0.84 | 0.82 | 0.88 |
| android-emu | eg2-740m-litertlm | LiteRT-LM cpu | 256 | 256 | 9 / 10527 | 94 / 230 | 173 / 707 | 0.84 | 0.80 | 0.89 |
| android-emu | eg2-740m-litertlm | LiteRT-LM cpu | 512 | 768 | 4 / 1510 | 93 / 310 | 173 / 716 | 0.84 | 0.85 | 0.93 |
| android-emu | eg2-740m-litertlm | LiteRT-LM cpu | 512 | 256 | 4 / 1510 | 93 / 310 | 173 / 716 | 0.82 | 0.82 | 0.93 |
| android-emu | eg2-q8_0 | CPU | 256 | 768 | 26050 / 4131 | 263 / 519 | 691 / 738 | 0.78 | 0.79 | 0.84 |
| android-emu | eg2-q8_0 | CPU | 256 | 256 | 26050 / 4131 | 263 / 519 | 691 / 738 | 0.78 | 0.80 | 0.86 |
| android-emu | eg2-q8_0 | CPU | 512 | 768 | 3570 / 356 | 233 / 932 | 692 / 760 | 0.81 | 0.84 | 0.88 |
| android-emu | eg2-q8_0 | CPU | 512 | 256 | 3570 / 356 | 233 / 932 | 692 / 760 | 0.79 | 0.80 | 0.89 |
| android-emu | granite-97m-r2-q8_0 | CPU | 256 | 384 | 1449 / 49 | 21 / 47 | 389 / 413 | 0.76 | 0.78 | 0.84 |
| android-emu | granite-97m-r2-q8_0 | CPU | 512 | 384 | 1605 / 68 | 33 / 149 | 390 / 421 | 0.78 | 0.81 | 0.88 |
| ios-sim | e5-small-q8_0 | CPU | 256 | 384 | 680 / 42 | 22 / 39 | 567 / 575 | 0.65 | 0.71 | 0.80 |
| ios-sim | e5-small-q8_0 | CPU | 512 (511) | 384 | 525 / 35 | 22 / 109 | 595 / 606 | 0.66 | 0.71 | 0.84 |
| ios-sim | eg2-270m-litertlm | LiteRT-LM cpu | 256 | 768 | 81 / 1252 | 65 / 117 | 300 / 825 | 0.84 | 0.82 | 0.88 |
| ios-sim | eg2-270m-litertlm | LiteRT-LM cpu | 256 | 256 | 81 / 1252 | 65 / 117 | 300 / 825 | 0.84 | 0.80 | 0.89 |
| ios-sim | eg2-270m-litertlm | LiteRT-LM cpu | 512 | 768 | 50 / 1178 | 57 / 122 | 309 / 966 | 0.84 | 0.85 | 0.93 |
| ios-sim | eg2-270m-litertlm | LiteRT-LM cpu | 512 | 256 | 50 / 1178 | 57 / 122 | 309 / 966 | 0.82 | 0.82 | 0.93 |
| ios-sim | eg2-740m-litertlm | LiteRT-LM cpu | 256 | 768 | 88 / 4175 | 77 / 116 | 290 / 890 | 0.84 | 0.82 | 0.88 |
| ios-sim | eg2-740m-litertlm | LiteRT-LM cpu | 256 | 256 | 88 / 4175 | 77 / 116 | 290 / 890 | 0.84 | 0.80 | 0.89 |
| ios-sim | eg2-740m-litertlm | LiteRT-LM cpu | 512 | 768 | 48 / 4469 | 99 / 257 | 306 / 628 | 0.84 | 0.85 | 0.93 |
| ios-sim | eg2-740m-litertlm | LiteRT-LM cpu | 512 | 256 | 48 / 4469 | 99 / 257 | 306 / 628 | 0.82 | 0.82 | 0.93 |
| ios-sim | eg2-q8_0 | CPU | 256 | 768 | 1326 / 434 | 219 / 414 | 709 / 732 | 0.79 | 0.79 | 0.84 |
| ios-sim | eg2-q8_0 | CPU | 256 | 256 | 1326 / 434 | 219 / 414 | 709 / 732 | 0.78 | 0.80 | 0.85 |
| ios-sim | eg2-q8_0 | CPU | 512 | 768 | 2592 / 422 | 577 / 2228 | 421 / 603 | 0.84 | 0.81 | 0.86 |
| ios-sim | eg2-q8_0 | CPU | 512 | 256 | 2592 / 422 | 577 / 2228 | 421 / 603 | 0.79 | 0.81 | 0.88 |
| ios-sim | granite-97m-r2-q8_0 | CPU | 256 | 384 | 435 / 52 | 19 / 43 | 547 / 572 | 0.76 | 0.74 | 0.85 |
| ios-sim | granite-97m-r2-q8_0 | CPU | 512 | 384 | 592 / 46 | 21 / 112 | 462 / 486 | 0.76 | 0.76 | 0.88 |
| macos | e5-small-q8_0 | Metal | 256 | 384 | 403 / 16 | 6.6 / 8.3 | 368 / 379 | 0.65 | 0.72 | 0.80 |
| macos | e5-small-q8_0 | Metal | 512 (511) | 384 | 445 / 15 | 6.1 / 10 | 369 / 390 | 0.66 | 0.71 | 0.84 |
| macos | e5-small-q8_0-cpu | CPU | 256 | 384 | 383 / 21 | 14 / 25 | 448 / 463 | 0.65 | 0.71 | 0.80 |
| macos | e5-small-q8_0-cpu | CPU | 512 (511) | 384 | 220 / 18 | 13 / 67 | 451 / 477 | 0.66 | 0.71 | 0.84 |
| macos | eg2-270m-litertlm | LiteRT-LM cpu | 256 | 768 | 8 / 943 | 79 / 150 | 136 / 538 | 0.84 | 0.82 | 0.88 |
| macos | eg2-270m-litertlm | LiteRT-LM cpu | 256 | 256 | 8 / 943 | 79 / 150 | 136 / 538 | 0.84 | 0.80 | 0.89 |
| macos | eg2-270m-litertlm | LiteRT-LM cpu | 512 | 768 | 21 / 2074 | 68 / 177 | 112 / 334 | 0.84 | 0.85 | 0.93 |
| macos | eg2-270m-litertlm | LiteRT-LM cpu | 512 | 256 | 21 / 2074 | 68 / 177 | 112 / 334 | 0.82 | 0.82 | 0.93 |
| macos | eg2-740m-litertlm | LiteRT-LM cpu | 256 | 768 | 16 / 1340 | 69 / 107 | 110 / 511 | 0.84 | 0.82 | 0.88 |
| macos | eg2-740m-litertlm | LiteRT-LM cpu | 256 | 256 | 16 / 1340 | 69 / 107 | 110 / 511 | 0.84 | 0.80 | 0.89 |
| macos | eg2-740m-litertlm | LiteRT-LM cpu | 512 | 768 | 2 / 539 | 75 / 184 | 121 / 638 | 0.84 | 0.85 | 0.93 |
| macos | eg2-740m-litertlm | LiteRT-LM cpu | 512 | 256 | 2 / 539 | 75 / 184 | 121 / 638 | 0.82 | 0.82 | 0.93 |
| macos | eg2-bf16 | Metal | 256 | 768 | 612 / 67 | 40 / 83 | 791 / 811 | 0.79 | 0.84 | 0.84 |
| macos | eg2-bf16 | Metal | 256 | 256 | 612 / 67 | 40 / 83 | 791 / 811 | 0.79 | 0.79 | 0.85 |
| macos | eg2-bf16 | Metal | 512 | 768 | 1668 / 94 | 57 / 86 | 651 / 703 | 0.81 | 0.82 | 0.88 |
| macos | eg2-bf16 | Metal | 512 | 256 | 1668 / 94 | 57 / 86 | 651 / 703 | 0.79 | 0.84 | 0.88 |
| macos | eg2-q8_0 | Metal | 256 | 768 | 961 / 64 | 24 / 41 | 531 / 559 | 0.80 | 0.80 | 0.84 |
| macos | eg2-q8_0 | Metal | 256 | 256 | 961 / 64 | 24 / 41 | 531 / 559 | 0.78 | 0.78 | 0.85 |
| macos | eg2-q8_0 | Metal | 512 | 768 | 1862 / 118 | 42 / 83 | 422 / 448 | 0.81 | 0.82 | 0.86 |
| macos | eg2-q8_0 | Metal | 512 | 256 | 1862 / 118 | 42 / 83 | 422 / 448 | 0.78 | 0.81 | 0.88 |
| macos | eg2-q8_0-cpu | CPU | 256 | 768 | 631 / 351 | 224 / 438 | 656 / 703 | 0.79 | 0.79 | 0.84 |
| macos | eg2-q8_0-cpu | CPU | 256 | 256 | 631 / 351 | 224 / 438 | 656 / 703 | 0.78 | 0.80 | 0.85 |
| macos | eg2-q8_0-cpu | CPU | 512 | 768 | 845 / 415 | 227 / 850 | 646 / 657 | 0.84 | 0.81 | 0.86 |
| macos | eg2-q8_0-cpu | CPU | 512 | 256 | 845 / 415 | 227 / 850 | 646 / 657 | 0.79 | 0.81 | 0.88 |
| macos | granite-97m-r2-q8_0 | Metal | 256 | 384 | 607 / 24 | 6.3 / 8.5 | 327 / 338 | 0.75 | 0.74 | 0.85 |
| macos | granite-97m-r2-q8_0 | Metal | 512 | 384 | 268 / 15 | 6.6 / 12 | 377 / 386 | 0.76 | 0.78 | 0.88 |
| macos | granite-97m-r2-q8_0-cpu | CPU | 256 | 384 | 548 / 40 | 22 / 42 | 358 / 379 | 0.76 | 0.74 | 0.85 |
| macos | granite-97m-r2-q8_0-cpu | CPU | 512 | 384 | 545 / 30 | 21 / 109 | 398 / 408 | 0.76 | 0.76 | 0.88 |

## Peso dell'app (release, modello escluso)

| piattaforma | app vuota | llamadart (llama.cpp + LiteRT-LM) | aggiunto |
|---|---|---|---|
| macOS `.app` (universal) | 37 MB | 160 MB | +123 MB |
| Android APK arm64-v8a (`--split-per-abi`) | 14.8 MiB | 115.7 MiB (44 MiB gzip) | +101 MiB |
| iOS `Runner.app` (`--no-codesign`) | 14 MB | 78 MB | +64 MB |

Nell'APK le librerie native valgono 54 MiB LiteRT-LM (+ Dawn/WebGPU, OpenCL, Gemma constraint provider) e 47 MiB
llama.cpp, di cui 25 MiB `libggml-vulkan.so` e 7 varianti `libggml-cpu-android_*` da ~1.5 MiB. Con un solo runtime
(`llamadart_native_runtimes: [llama_cpp]`, backend `cpu`, `cpu_profile: compact`) si stima ~+20 MiB; non misurato.
Su macOS LiteRT-LM porta ~86 MB (LiteRtLm, LiteRt, WebGPU accelerator/sampler, Dawn), llama.framework 36 MB.

Modelli (download a parte): EG2 Q8_0 310 MB, EG2 BF16 558 MB, EG2 `.litertlm` 740m 485 MB e 270m 165 MB,
granite-97m-r2 Q8_0 115 MB, e5-small Q8_0 132 MB.

## Qualità

- EG2 Q8_0 vs BF16 (macOS Metal, stesse 80 email): coseno medio 0.9999, minimo 0.9998 sia a 256 sia a 512 token.
  Q8_0 Metal vs Q8_0 CPU: 0.9998 / 0.9995.
- EG2 GGUF BF16 vs `.litertlm` 740m: coseno medio 0.974, minimo 0.955: i bundle LiteRT danno vettori diversi (e qui
  un po' migliori: zero-shot 0.84 contro 0.79-0.81).
- `.litertlm` 740m e 270m danno embedding di testo identici (coseno 1.0000): il 740m aggiunge solo le torri
  immagine/audio. Per il testo basta il 270m (165 MB contro 485 MB).
- Stesse accuratezze tra piattaforme per lo stesso modello (differenze ≤ 0.04 da aritmetica CPU/Metal).

## Note ed errori

- `.litertlm` su llamadart: funziona su macOS, simulatore iOS ed emulatore Android (CPU, `LiteRtLmModelParams
  (embeddingEngine: true)`). L'engine di embedding LiteRT-LM non espone `tokenize`/`detokenize` (`LlamaException:
  Conversation and tokenizer APIs are unavailable on a LiteRT-LM embedding engine`): il troncamento usa il tokenizer
  del GGUF EG2. `load` è pigro: il costo reale (0.5-10 s) cade sul primo embed.
- Vulkan su Android: non provabile sull'emulatore. `ComputeDevice.gpu` → `LlamaException: ComputeDevice.gpu needs
  the vulkan backend for llama.cpp on android, but no GPU device is available (devices: CPU)`: l'emulatore espone
  Vulkan via lavapipe (software), che ggml non conta come GPU. Serve un device fisico.
- e5-small: `cstr/multilingual-e5-small-GGUF` (quello del vetting) non si carica (`Failed to load model`, tokenizer
  `llama` su architettura `bert`); `keisuke-miyako/…-q8_0` si carica ma ha tokenizer WordPiece al posto di
  SentencePiece (zero-shot 0.25, inutilizzabile). Usato `TwinSunsLLC/multilingual-e5-small-gguf` (tokenizer `t5`,
  base intfloat, MIT, 2.2k download).
- Il simulatore iOS non passa le variabili d'ambiente all'app (`HOME` e `SIMCTL_CHILD_*` assenti in
  `Platform.environment`): la configurazione passa da `Documents/job.json`. Su Android la cartella creata da
  `adb push` è di `shell` e l'app non la legge: serve `adb root` + `chown` all'uid dell'app.
