---
status: Accettato
date: 2026-11-04
---

# IA sul dispositivo: llamadart e EmbeddingGemma-2

Le funzionalità IA di Postino girano interamente sul dispositivo, sulle 5 piattaforme (Android, iOS, macOS, Windows, Linux), a partire dall'Etichettatura automatica. Il runtime è **`llamadart`** (llama.cpp, licenza MIT), l'unico che copre insieme gli embedding di oggi e l'LLM di domani. Lo spike #103 ha misurato i candidati; questa ADR ne registra l'esito.

**Modello.** EmbeddingGemma-2 text 270m (Apache-2.0, non gated), con testo troncato a 256 token e vettori da 768 dimensioni normalizzati L2. Il formato dipende dal sistema operativo **e dall'architettura del processo** (`Abi.current()`), non solo dal sistema:

- su macOS, iOS e Android arm64 (il perimetro verificato dallo spike) il formato `.litertlm` (165 MB), il più accurato misurato (centroide 0.91–0.93, zero-shot 0.82–0.84) e con la RAM più bassa. LiteRT-LM calcola gli embedding solo su CPU e solo su arm64;
- su ogni altra piattaforma o architettura il GGUF Q8_0: Windows e Linux, dove llamadart non carica `.litertlm` (`LlamaUnsupportedException`), ma anche macOS Intel o sotto Rosetta e Android x86_64. Il GGUF Q8_0 pesa 310 MB, è equivalente in accuratezza entro 0.02 (coseno medio con BF16 0.9999) ed è più veloce e leggero del BF16.

**File dei modelli (#135).** URL fissati al commit del repository Hugging Face, dimensione e SHA-256 verificati il 2026-11-05; il download scarta un file che non corrisponde. Il GGUF è quello di `ggml-org`, l'organizzazione di llama.cpp: ufficiale, non di terzi.

| Formato | Id del modello | URL | Byte | SHA-256 |
|---|---|---|---|---|
| `.litertlm` | `embeddinggemma-2-270m-litertlm` | `huggingface.co/litert-community/embeddinggemma-2-text-270m-litert-lm/resolve/9be6e8b90982095dc05c2bd162e4b954ee4dbac7/embeddinggemma-2-text-270m.litertlm` | 164626432 | `2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb` |
| GGUF Q8_0 | `embeddinggemma-2-270m-gguf-q8_0` | `huggingface.co/ggml-org/embeddinggemma-2-GGUF/resolve/6ea3e3a309d12a4779cfda98b8c19800d2d5da71/embeddinggemma-2-Q8_0.gguf` | 309855456 | `2188ac1deca4b77dffefd603c2776a9d76d9d74ec01841392982ebb840b09135` |

L'id del modello accompagna ogni embedding salvato: cambiando formato (per esempio un Mac Intel migrato a Apple Silicon) gli embedding e i prototipi già salvati non si confrontano con i nuovi e si ricalcolano.

**Troncamento a 256 token (#135).** Il testo da embeddare è `task: classification | query: <testo>`; prefisso e token speciali contano 9 token, quindi restano 247 token di testo.

- GGUF: troncamento esatto con il tokenizer del modello (`tokenize` senza token speciali, taglio a 247, `detokenize`, ricontrollo).
- `.litertlm`: LiteRT-LM in modalità embedding non espone il tokenizer e non tronca mai (un input troppo lungo lancia `LlamaInferenceException`). Caricare anche il GGUF solo per il tokenizer costerebbe 310 MB e un secondo motore: si tronca invece per caratteri, a **850**, con un tetto rigido di **960 byte UTF-8**. Misura col tokenizer del GGUF sulle 80 email dello spike, nel formato di Postino (corpo già tagliato a 1000 caratteri): 3.7 caratteri per token in mediana (IT 3.58, EN 3.92), 2.77 al minimo; 18 email su 80 superano i 247 token, e la più corta delle loro prime 247 parti è di 854 caratteri. Con 850 caratteri nessuna email del dataset supera i 256 token; un testo più denso di token (codice, lingue non latine) può superarli di poco, senza errori. Il tetto in byte garantisce il contesto: il tokenizer Gemma fa al massimo un token per byte, quindi al massimo 960 + 9 token, sotto i 1024 dell'encoder.

**Come si sceglie l'Etichetta.** Centroide degli esempi dell'Account, cioè le email già nell'Etichetta. Lo zero-shot (coseno tra l'email e "nome: descrizione" dell'Etichetta automatica) serve solo all'avvio a freddo, con una soglia di margine. Al massimo un'Etichetta per email, solo sopra una soglia; si saltano le email che hanno già un'Etichetta dell'utente e si considerano solo le email nuove dopo l'attivazione.

Soglie misurate (#135) con il `.litertlm` sulle 80 email sintetiche dello spike: con margine 0.02 il centroide ha precisione 1.00 e copertura 0.66, lo zero-shot 0.95 e 0.74. Il coseno minimo 0.30 è inerte: i coseni top-1 di EmbeddingGemma-2 stanno tra 0.66 e 0.94, e giuste e sbagliate si sovrappongono. Simulando email fuori da ogni Etichetta (togliendo la propria) il margine 0.02 ne etichetta per errore il 34% col centroide e il 23% con lo zero-shot; un coseno minimo le ridurrebbe solo con valori diversi per centroide (≥0.88) e zero-shot (≥0.75–0.78), a scapito della copertura. Il dataset non ha email reali fuori dalle Etichette: margine 0.02 e coseno 0.30 restano finché non si misurano su posta vera.

**Embedding non sincronizzati.** Embedding di formati diversi non sono confrontabili (coseno medio 0.974 tra `.litertlm` e GGUF). Centroidi ed embedding si calcolano e restano sul dispositivo: non entrano mai nelle Impostazioni di Postino su Drive. Ogni dispositivo etichetta da sé e, prima di scrivere, ricontrolla che l'email non abbia già un'Etichetta. Controllo e scrittura non sono atomici: il raro caso di due Etichette sulla stessa email è accettato (mappa #102), senza coordinamento tra dispositivi.

**Distribuzione dei modelli.** I modelli non sono inclusi nell'app: si scaricano alla prima attivazione di un'Etichetta automatica. In Wi-Fi il download parte subito; su qualunque rete diversa dal Wi-Fi, o non determinabile (per esempio sul desktop), solo dopo la conferma dell'utente.

**Privacy.** Tutto sul dispositivo: nessun cloud, nessun invio del contenuto dei messaggi, nessuna telemetria dell'IA. Se mai si usasse ONNX Runtime, la telemetria di ORT-GenAI va disattivata. Nessun fine tuning: il modello resta quello pubblicato e l'adattamento all'Account sta nei centroidi.

## Rapporto con le altre ADR

- [ADR 0001](0001-nessun-backend.md): conferma e prolunga "nessun backend". L'inferenza non passa da nessun server, quindi nessuna API a pagamento e nessun contenuto di posta esce dal dispositivo.
- [ADR 0004](0004-impostazioni-su-drive.md): la configurazione delle Etichette automatiche (quali Etichette, descrizioni) vive nelle Impostazioni di Postino su Drive e segue le loro regole: questa ADR estende l'elenco delle voci sincronizzate della 0004. I modelli e gli embedding no, per il motivo sopra.
- [ADR 0008](0008-motore-di-sincronizzazione.md): l'Etichetta assegnata si scrive sul Provider come ogni altra modifica, tramite la coda offline del motore di sincronizzazione, con i suoi intenti idempotenti e il rilevamento dei Conflitti.

## Alternative considerate

- **Flutter Edge AI** (LiteRT-LM): stesso modello, `.litertlm` su tutte e 5 le piattaforme, download manager integrato e circa metà del peso (+52 MB macOS, +40 MB iOS, +42 MiB APK arm64). Scartata perché non copre i futuri LLM GGUF: per quelli userebbe comunque llamadart, e avremmo due runtime. Resta il ripiego se il peso dell'app diventa il problema.
- **Altri modelli**: granite-97m-r2 (115 MB) ed e5-small (132 MB) sono più piccoli e veloci ma meno accurati (centroide 0.88 e 0.84); i loro GGUF sono conversioni di singoli utenti, da rifare da noi. EmbeddingGemma-2 740m dà gli stessi embedding di testo del 270m con il triplo del peso.
- **kNN sugli esempi**: meno accurato del centroide e più costoso. Scartata.
- **Servizio cloud o backend**: contro l'ADR 0001 e la privacy. Scartata.
- **Fine tuning**: complessità e pesi per Account senza un bisogno misurato. Scartata.

## Conseguenze

- Peso dell'app (release, modelli esclusi): llamadart include sia llama.cpp sia LiteRT-LM, quindi +64 MB su iOS, +101 MiB sull'APK arm64 (44 MiB compresso), +123 MB su macOS universal. È il prezzo dell'unico runtime.
- Due formati di modello da gestire, per sistema e architettura; con `.litertlm` il troncamento a 256 token è approssimato (sopra).
- Il caricamento del modello costa da 0.2 a 2.6 s (GGUF) o da 0.5 a 10 s sul primo embed (`.litertlm`); sull'emulatore il primo avvio a freddo del GGUF è arrivato a 26 s. Il motore non blocca la sincronizzazione: si carica in background al primo embed dopo il download e, finché non è pronto, quella sincronizzazione non classifica; lo fa la successiva. Su un Mac Apple Silicon (#135): `.litertlm` pronto in 0.9–3.8 s (caricamento più primo embed), poi 30–60 ms per email; GGUF in 1.4–4.9 s, poi 20–45 ms.
- llamadart richiede Flutter 3.38 o successivi (Edge AI richiederebbe 3.44): nessun ostacolo oggi.
- **Android ARM32 escluso (#135):** llamadart 0.17.5 non ha un runtime per armeabi-v7a, quindi l'APK contiene solo `arm64-v8a` e `x86_64` (`ndk.abiFilters` e `packaging` in `android/app/build.gradle.kts`: il plugin Flutter riaggiunge armeabi-v7a ai filtri). I dispositivi ARM a 32 bit non possono installare Postino; l'APK è più piccolo.
- **Sistemi minimi alzati (#135):** iOS 16.4 e macOS 14.0 (Sonoma), richiesti dai pacchetti companion di llamadart. Restano esclusi gli utenti su versioni precedenti.
- Le companion Apple (`llamadart_llama_cpp_flutter`, `llamadart_litert_lm_flutter`) esistono solo come Swift package: Swift Package Manager è attivo per il progetto (`flutter: config: enable-swift-package-manager: true` nel `pubspec.yaml`), gli altri plugin restano su CocoaPods. I binari nativi di llamadart sono scaricati al build con checksum fissati nel pacchetto: non si usano gli override `llamadart_native_tag`/`_repository`/`_path`, che li disattivano.

## Punti aperti

La decisione è accettata ma condizionata a questi punti: se le misure sui dispositivi fisici la smentiscono, si rivede con una nuova ADR. Da verificare (lo spike non ha usato dispositivi fisici; le latenze di simulatore ed emulatore non valgono per un telefono):

- misure su un Android di fascia media e su un iPhone fisici;
- Windows e Linux, mai misurati, compreso il GGUF Q8_0;
- Vulkan e OpenCL su hardware vero (su Android llamadart usa la CPU di default; sull'emulatore Vulkan non parte);
- batteria e temperatura durante l'Etichettatura automatica di un Account con molti messaggi nuovi;
- soglie (coseno minimo, margine) su posta reale, comprese le email fuori da ogni Etichetta;
- iOS 16.4 è il minimo di build: upstream ha verificato LiteRT-LM su un iPhone con iOS 18.3.

Le scelte sulle funzionalità LLM restano alla mappa #102.
