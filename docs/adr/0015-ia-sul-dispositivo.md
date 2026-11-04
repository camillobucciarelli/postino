---
status: Accettato
date: 2026-11-04
---

# IA sul dispositivo: llamadart e EmbeddingGemma-2

Le funzionalità IA di Postino girano interamente sul dispositivo, sulle 5 piattaforme (Android, iOS, macOS, Windows, Linux), a partire dall'Etichettatura automatica. Il runtime è **`llamadart`** (llama.cpp, licenza MIT), l'unico per gli embedding di oggi e per l'LLM di domani. Lo spike #103 ha misurato i candidati; questa ADR ne registra l'esito.

**Modello.** EmbeddingGemma-2 text 270m (Apache-2.0, non gated), con testo troncato a 256 token e vettori da 768 dimensioni:

- su macOS, iOS e Android il formato `.litertlm` (165 MB), il più accurato misurato (centroide 0.91–0.93, zero-shot 0.82–0.84) e con la RAM più bassa;
- su Windows e Linux llamadart non carica `.litertlm` (`LlamaUnsupportedException`): lì il GGUF Q8_0 (310 MB), equivalente in accuratezza entro 0.02 (coseno medio con BF16 0.9999) e più veloce e leggero del BF16.

**Classificazione.** Centroide degli esempi dell'Account, cioè le email già nell'Etichetta. Lo zero-shot (coseno tra l'email e "nome: descrizione" dell'Etichetta automatica) serve solo all'avvio a freddo, con una soglia di margine. Al massimo un'Etichetta per email, solo sopra una soglia; si saltano le email che hanno già un'Etichetta dell'utente e si considerano solo le email nuove dopo l'attivazione.

**Embedding non sincronizzati.** Embedding di formati diversi non sono confrontabili (coseno medio 0.974 tra `.litertlm` e GGUF). Centroidi ed embedding si calcolano e restano sul dispositivo: non entrano mai nelle Impostazioni di Postino su Drive. Ogni dispositivo classifica da sé e, prima di scrivere, ricontrolla che l'email non abbia già un'Etichetta.

**Distribuzione dei modelli.** I modelli non sono inclusi nell'app: si scaricano alla prima attivazione di un'Etichetta automatica. In Wi-Fi il download parte subito; su rete cellulare solo dopo la conferma dell'utente.

**Privacy.** Tutto sul dispositivo: nessun cloud, nessun invio del contenuto dei messaggi, nessuna telemetria dell'IA. Se mai si usasse ONNX Runtime, la telemetria di ORT-GenAI va disattivata. Nessun fine tuning: il modello resta quello pubblicato e l'adattamento all'Account sta nei centroidi.

## Rapporto con le altre ADR

- [ADR 0001](0001-nessun-backend.md): conferma e prolunga "nessun backend". L'inferenza non passa da nessun server, quindi nessuna API a pagamento e nessun contenuto di posta esce dal dispositivo.
- [ADR 0004](0004-impostazioni-su-drive.md): la configurazione delle Etichette automatiche (quali Etichette, descrizioni) vive nelle Impostazioni di Postino su Drive e segue le loro regole. I modelli e gli embedding no, per il motivo sopra.
- [ADR 0008](0008-motore-di-sincronizzazione.md): l'Etichetta assegnata si scrive sul Provider come ogni altra modifica, tramite la coda offline del motore di sincronizzazione, con i suoi intenti idempotenti e il rilevamento dei Conflitti.

## Alternative considerate

- **Flutter Edge AI** (LiteRT-LM): stesso modello, `.litertlm` su tutte e 5 le piattaforme, download manager integrato e circa metà del peso (+52 MB macOS, +40 MB iOS, +42 MiB APK arm64). Scartata perché non copre i futuri LLM GGUF: per quelli userebbe comunque llamadart, e avremmo due runtime. Resta il ripiego se il peso dell'app diventa il problema.
- **Altri modelli**: granite-97m-r2 (115 MB) ed e5-small (132 MB) sono più piccoli e veloci ma meno accurati (centroide 0.88 e 0.84); i loro GGUF sono conversioni di singoli utenti, da rifare da noi. EmbeddingGemma-2 740m dà gli stessi embedding di testo del 270m con il triplo del peso.
- **kNN sugli esempi**: meno accurato del centroide e più costoso. Scartata.
- **Servizio cloud o backend**: contro l'ADR 0001 e la privacy. Scartata.
- **Fine tuning**: complessità e pesi per Account senza un bisogno misurato. Scartata.

## Conseguenze

- Peso dell'app (release, modelli esclusi): llamadart include sia llama.cpp sia LiteRT-LM, quindi +64 MB su iOS, +101 MiB sull'APK arm64 (44 MiB compresso), +123 MB su macOS universal. È il prezzo dell'unico runtime.
- Due formati di modello da gestire, per piattaforma, e un tokenizer di EmbeddingGemma-2 per troncare il testo con `.litertlm`, che non espone il suo.
- Il caricamento del modello costa da 0.2 a 2.6 s (GGUF) o da 0.5 a 10 s sul primo embed (`.litertlm`): il motore non deve bloccare la sincronizzazione.
- llamadart richiede Flutter 3.38 o successivi (Edge AI richiederebbe 3.44): nessun ostacolo oggi.

## Punti aperti

Da verificare prima di considerare chiusa la scelta (lo spike non ha usato dispositivi fisici; le latenze di simulatore ed emulatore non valgono per un telefono):

- misure su un Android di fascia media e su un iPhone fisici;
- Windows e Linux, mai misurati, compreso il GGUF Q8_0;
- Vulkan e OpenCL su hardware vero (su Android llamadart usa la CPU di default; sull'emulatore Vulkan non parte);
- batteria e temperatura durante la classificazione di una casella piena;
- GGUF di EmbeddingGemma-2 ufficiale o convertito da noi, non di terzi.

Le scelte sulle funzionalità LLM restano alla mappa #102. Il gestore dei modelli e il motore sono altri ticket.
