# Dichiarazioni per la Play Console

Risposte per la pagina **Monitora e migliora → Norme e programmi → Contenuti dell'app** (in inglese *Policy → App content*) e per i permessi, della variante Android «store» (#345). Requisiti verificati sulle pagine di Google il 16/11/2026; nessuna pagina mostra una data di ultima modifica. Ciò che non ho trovato scritto su una pagina ufficiale è segnato **non verificato**.

## 1. Norme sulla privacy

URL: https://postino.camillobucciarelli.dev/privacy.html. Google lo chiede **anche se l'app non raccoglie dati**, pubblico, in HTTPS, non PDF, e lo vuole anche dentro l'app (c'è: Impostazioni → Informativa sulla privacy) ([preparare l'app per la revisione](https://support.google.com/googleplay/android-developer/answer/9859455), [Sicurezza dei dati](https://support.google.com/googleplay/android-developer/answer/10787469)).

**Da aggiornare prima dell'invio** (il sito è fuori da #345, lo fa il titolare): l'informativa del 15/11/2026 dice che il file su Drive non contiene «mai posta, password o token», ma con #321 (ADR 0019, fette 3 e 4 unite) contiene anche le credenziali degli Account, cifrate con una chiave che resta sui dispositivi. Dice anche che Android controlla gli aggiornamenti sul sito: la variante Play non lo fa (fetta 1 di #345). Infine non nomina la fotocamera (usata solo per «Inquadra il QR», l'immagine non esce dal dispositivo).

## 2. Sicurezza dei dati (Data safety)

Coerente con [app-privacy.md](app-privacy.md) (App Store: «Dati non raccolti»). Fonte: [Sicurezza dei dati](https://support.google.com/googleplay/android-developer/answer/10787469).

| Domanda | Risposta |
|---|---|
| La tua app raccoglie o condivide uno dei tipi di dati utente richiesti? | **No** |

Con «No» la Console non chiede né la cifratura in transito né la cancellazione su richiesta: quelle domande compaiono solo per i dati raccolti. La scheda mostrerà «Nessun dato raccolto» e «Nessun dato condiviso con terze parti».

Perché «No», punto per punto. Google chiama «raccolta» il dato che lascia il dispositivo, anche verso server di terzi; «condivisione» il trasferimento a terzi. Postino non ha backend (ADR 0001) e nessun SDK di analytics, pubblicità o crash reporting (`pubspec.yaml`).

| Dato che esce dal dispositivo | Dove va | Perché non va dichiarato |
|---|---|---|
| Posta, indirizzi, password IMAP, token OAuth | Solo al Provider che l'utente collega (Gmail, Microsoft, iCloud, server IMAP/SMTP) | È la funzione richiesta dall'utente verso il suo stesso account: trasferimento avviato dall'utente, che si aspetta di mandare la posta al suo Provider ([esenzione](https://support.google.com/googleplay/android-developer/answer/10787469): «user-initiated action»). Lo sviluppatore non lo riceve. **Interpretazione**, non una frase di Google sui client email: la pagina non nomina il caso. |
| Impostazioni e credenziali sincronizzate | Cartella `appDataFolder` del Google Drive dell'utente, file AES-256-GCM | Cifrato end-to-end con una chiave che resta sui dispositivi dell'utente (ADR 0019): illeggibile per chiunque altro, sviluppatore compreso. Google esclude i dati cifrati end-to-end e il caricamento sul cloud dell'utente stesso. |
| Testo dei messaggi per l'Etichettatura automatica | Nessun luogo | Elaborato solo sul dispositivo (ADR 0015). |
| Download del modello | Richiesta a `huggingface.co` | Non porta dati dell'utente (URL fisso, verifica SHA-256). |
| Ricerca della configurazione IMAP | Autoconfig del dominio dell'utente, DNS di Google, database di Thunderbird | Parte del collegamento dell'Account chiesto dall'utente; non porta posta né password. |
| Immagine della fotocamera («Inquadra il QR») | Nessun luogo | Il QR si decodifica sul dispositivo (ML Kit). |
| Controllo degli aggiornamenti dal sito | Nessun luogo nella variante Play | Spento nella variante «store» (fetta 1 di #345). Se la fetta 1 non lo spegnesse, il punto va rivisto. |
| Segnalazione di un problema | Email dall'Account dell'utente allo sviluppatore | Vedi sotto. |

**Segnalazione di un problema.** È la sola via con cui lo sviluppatore riceve dati: un'email che l'utente rilegge e decide di inviare. Google non ha l'«esclusione facoltativa» di Apple. La scelta resta quella fatta per l'App Store (non dichiarata), per coerenza tra i due store. Se il titolare preferisce dichiararla, le risposte sono pronte:

- Sì, l'app raccoglie dati. Tipi: **Informazioni personali → Indirizzo email**; **Informazioni e prestazioni dell'app → Log degli arresti anomali** e **Altri dati diagnostici**; **Messaggi → Email** (il log può contenere oggetti e indirizzi).
- Per ognuno: raccolto, non condiviso; non elaborato in modo temporaneo; **facoltativo** (l'utente sceglie); finalità **Funzionalità dell'app**.
- Cifrati in transito: **Sì** se il Provider dell'utente usa TLS (Postino esige SSL o STARTTLS); nel dubbio **No**.
- Cancellazione su richiesta: **Sì**, scrivendo a `camillo@bucciarelli.dev` (l'informativa promette la cancellazione entro 12 mesi e su richiesta).

## 3. Permessi della variante Play

Manifest unito di una build debug di `main` (16/11/2026), meno `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` che la variante Play non dichiara (fetta 1). **Da ricontrollare sul manifest unito della release `store`** quando la fetta 1 è unita: `aapt2 dump permissions <apk>` o *App bundle explorer* della Console.

| Permesso | Da dove | Perché | Dichiarazione Play |
|---|---|---|---|
| `INTERNET` | app | Parlare con i Provider, Drive, il download del modello | No |
| `ACCESS_NETWORK_STATE` | plugin | Sapere se c'è rete (coda offline, Wi-Fi per il modello) | No |
| `FOREGROUND_SERVICE` | app | Avviare il servizio delle Notifiche immediate | No (la dichiarazione è per tipo, sotto) |
| `FOREGROUND_SERVICE_SPECIAL_USE` | app | `ListeningService`, tipo `specialUse` | **Sì**, sezione 4 |
| `FOREGROUND_SERVICE_SHORT_SERVICE` | plugin `workmanager_android` (il suo `SystemForegroundService`) | Lavoro *expedited* di WorkManager | Il tipo `shortService` non compare nella tabella di Google, che però dice di non essere esaustiva: **non verificato**. Se la Console lo chiede, testo nella sezione 4. |
| `RECEIVE_BOOT_COMPLETED` | app (`BootReceiver`) e plugin | Riavviare le Notifiche immediate dopo il riavvio del telefono e rimettere in coda il controllo periodico | No |
| `POST_NOTIFICATIONS` | plugin `flutter_local_notifications` | Mostrare la posta nuova; Android 13+ lo chiede all'utente | No |
| `CAMERA` | plugin `mobile_scanner` | «Inquadra il QR» dell'Abbinamento (#321); chiesto solo al tocco | No |
| `VIBRATE`, `WAKE_LOCK` | plugin | Notifiche e lavoro in background | No |
| `…DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX | Permesso interno dell'app, generato | No |

I permessi che richiedono una dichiarazione propria sono altri (SMS, registro chiamate, posizione in background, tutti i file, accessibilità, ecc.: [elenco](https://support.google.com/googleplay/android-developer/answer/16558241)); nessuno è in Postino. `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` è ammesso solo se la funzione principale dell'app ne risente e, per la messaggistica, se l'app non può usare FCM ([Doze](https://developer.android.com/training/monitoring-device-state/doze-standby)): la variante Play non lo dichiara e apre invece la schermata di sistema (`ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`), che non chiede il permesso. Nessun permesso `AD_ID` nel manifest unito.

## 4. Servizi in primo piano (Foreground service permissions)

Google chiede, per ogni tipo dichiarato da un'app con target 34+: descrizione della funzione, impatto sull'utente se il compito viene rimandato o interrotto, **link a un video** che mostra i passi dell'utente per attivarla, e lo use case (da elenco o scritto a mano per `specialUse`). `specialUse` è ammesso «in limited scenarios», quando nessun altro tipo va bene; ogni tipo è soggetto a revisione ([dichiarazione](https://support.google.com/googleplay/android-developer/answer/13392821), [tipi di servizio](https://developer.android.com/develop/background-work/services/fgs/service-types)). Google non dice dove ospitare il video né quanto deve durare: un link YouTube **non in elenco** è la scelta comune (**non verificato** che sia l'unica accettata).

Perché non un altro tipo: `dataSync` con target 35+ si ferma dopo 6 ore ogni 24 e non si avvia da `BOOT_COMPLETED` ([timeout](https://developer.android.com/develop/background-work/services/fgs/timeout)); `remoteMessaging` è per i messaggi tra dispositivi, non per una casella IMAP (**non verificato** che Google lo accetti per l'email); `shortService` dura pochi minuti. Le stesse ragioni sono in `docs/research/notifiche-background-per-piattaforma.md`.

### Testo da incollare (inglese: lo legge il revisore)

Use case: **Other** (scritto a mano).

```
Feature: "Immediate notifications" (Settings > Device settings), off by default and turned on only by the user.

Description: Postino is an email client with no server of its own: it connects directly to the user's own mail providers. Most of them (any IMAP mailbox, iCloud, and Gmail through IMAP IDLE) offer no push service a third-party client could use, and Postino has no backend to receive Firebase Cloud Messaging. When the user turns on Immediate notifications, the specialUse foreground service ListeningService keeps the app's engine alive with Postino closed so that it can hold the IMAP IDLE connections open and show new mail as soon as it arrives (Microsoft accounts are polled every 60 seconds instead). The service shows a persistent notification, "Postino is listening", which opens the unified inbox. The service stops as soon as the user turns the feature off. It does nothing else: no location, no media, no data upload.

Impact if deferred or interrupted: new mail is no longer shown in real time. Postino falls back to the periodic background check (WorkManager, about every 15 minutes), so notifications arrive late, up to 15 minutes or more under Doze. No data is lost: the next sync, or the next time the app is opened, catches up.

Why not another type: dataSync is limited to 6 hours per 24 hours on Android 15+ and cannot start after a reboot, while the IDLE connection must stay open continuously; shortService lasts only a few minutes; there is no push alternative without a server.

Video: <VIDEO_URL>
```

Se la Console chiede anche `shortService` (sezione 3):

```
Feature: none of Postino's own. The type is declared by the WorkManager library (androidx.work SystemForegroundService) for expedited background work, which WorkManager may run as a short foreground service. Postino's background mail check uses periodic WorkManager work.
Impact if deferred or interrupted: the background mail check runs later; nothing is lost.
Video: <VIDEO_URL> (same video; the periodic check needs no user step)
```

Il valore di `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` nel manifest («Email client keeping IMAP IDLE connections open, chosen by the user, to show new mail in real time; no push service is available for these accounts.») dice la stessa cosa e resta com'è.

### Scaletta del video (da registrare a cura del titolare)

Durata 30–60 s, telefono o emulatore con la build Play, lingua **inglese**, nessun dato personale (casella demo). Registrazione dello schermo di Android (*Registra schermo* nelle Impostazioni rapide) o `adb shell screenrecord /sdcard/fgs.mp4`.

1. Postino aperto sulla Posta unificata con la casella demo collegata (5 s).
2. Menu ☰ → **Settings** → **Device settings**: si vede l'interruttore **Immediate notifications** spento e il suo testo («New mail arrives in real time, even with Postino closed…») (10 s).
3. Tocco sull'interruttore: compare la notifica fissa **«Postino is listening»**; abbassare la tendina per mostrarla. Se compare la richiesta di escludere Postino dall'ottimizzazione batteria, mostrarla e accettarla (10–15 s).
4. Chiudere Postino (scorrerlo via dalle app recenti): la notifica fissa resta (5 s).
5. Da un altro dispositivo o dal computer, mandare un'email alla casella demo: la notifica della posta nuova arriva in pochi secondi con Postino chiuso (10–15 s).
6. Riaprire Postino → Settings → Device settings → spegnere **Immediate notifications**: la notifica fissa sparisce (5–10 s).

Caricare su YouTube come **non in elenco** e mettere il link al posto di `<VIDEO_URL>`.

## 5. Classificazione dei contenuti (questionario IARC)

Obbligatoria: un'app senza classificazione può essere rimossa ([classificazione](https://support.google.com/googleplay/android-developer/answer/9898843)). Indirizzo email per IARC: `camillo@bucciarelli.dev`. I nomi esatti delle domande si vedono solo in Console (**non verificati**); le risposte seguono il [questionario Apple](app-privacy.md#5-questionario-sulletà).

| Domanda | Risposta |
|---|---|
| Categoria | **Utility, produttività, comunicazione o altro** (non gioco, non social, non negozio) |
| Violenza, paura, sessualità, linguaggio volgare, droghe, alcol, tabacco, gioco d'azzardo, contenuti grezzi | **No** a tutte: Postino non produce contenuti, mostra la posta dell'utente |
| Gli utenti possono interagire o scambiarsi contenuti? | **Sì**: è un client email, l'utente scrive a chiunque |
| L'app condivide la posizione dell'utente con altri utenti? | No |
| L'app consente acquisti di beni digitali? | No |
| L'app è un browser web o un motore di ricerca / dà accesso illimitato a internet? | No: i link si aprono nel browser di sistema; «Vedi originale» è una WebView senza JavaScript (ADR 0007) |
| Contiene materiale che promuove o mostra prodotti di tabacco, alcol, armi? | No |

Esito atteso: PEGI 3 / ESRB Everyone / USK 0 con l'elemento interattivo «Gli utenti interagiscono». **Non verificato**: lo calcola IARC.

## 6. Pubblico di destinazione e contenuti

Fonte: [pubblico di destinazione](https://support.google.com/googleplay/android-developer/answer/9867159).

- Fasce d'età: **solo 18 anni e oltre**. Postino non è pensata per i minori e così le norme per le famiglie (sotto i 13) e gli obblighi per i minori di alcuni Paesi (13–17) non si applicano. «Restrict Minor Access» (blocco agli utenti che Google ritiene minorenni): **no**, non serve e toglierebbe utenti adulti mal classificati.
- L'app potrebbe attrarre involontariamente i bambini? **No**.

## 7. Altre dichiarazioni di «Contenuti dell'app»

| Dichiarazione | Risposta | Fonte |
|---|---|---|
| Annunci | **No**, l'app non contiene annunci | [preparare l'app per la revisione](https://support.google.com/googleplay/android-developer/answer/9859455) |
| Accesso all'app | **Tutte o alcune funzionalità sono limitate**: serve una casella email. Istruzioni e credenziali (fino a 5 gruppi, più un campo per OTP o MFA) in [play-note-revisione.md](play-note-revisione.md) | idem |
| ID pubblicità | **No**, l'app non usa l'ID pubblicità (nessun `AD_ID` nel manifest unito) | [ID pubblicità](https://support.google.com/googleplay/android-developer/answer/6048248) |
| App per le notizie | **No** | non verificato (nessuna pagina trovata sulla dichiarazione) |
| App governative | **No** | [governative](https://support.google.com/googleplay/android-developer/answer/9514050) |
| Funzionalità finanziarie | **Nessuna** | idem |
| App per la salute | **Nessuna funzione sanitaria** (Google la chiede a tutte le app, anche solo in test) | [salute](https://support.google.com/googleplay/android-developer/answer/14738291) |
| App COVID-19 | No (se la Console la mostra ancora) | non verificato |
| Sicurezza dei dati | sezione 2 | |
| Servizi in primo piano | sezione 4 | |

## 8. Altre regole che toccano Postino

- **Aggiornamenti fuori da Play.** Un'app distribuita su Play non può modificarsi, sostituirsi o aggiornarsi se non con il meccanismo di Play, né scaricare codice eseguibile (dex, JAR, `.so`) da altre fonti ([Device and Network Abuse](https://support.google.com/googleplay/android-developer/answer/9888379)). Per questo la variante «store» non mostra l'avviso che rimanda all'APK del sito (fetta 1). Il modello dell'Etichettatura automatica è un file di dati (pesi), non codice: la policy non lo nomina, quindi **non verificato**, ma il divieto riguarda il codice eseguibile.
- **Livello API target.** Dal 31/08/2026 nuove app e aggiornamenti devono avere target **API 36** ([requisiti](https://developer.android.com/google/play/requirements/target-sdk)); Postino ha `targetSdk` 36. La proroga si poteva chiedere fino all'1/11/2026.
- **Crittografia ed export.** Play non ha un questionario come quello di Apple: alla creazione dell'app si accetta la dichiarazione sulle **leggi statunitensi sull'esportazione**, e Google ricorda che le regole USA sulla crittografia valgono anche per sviluppatori fuori dagli USA ([export](https://support.google.com/googleplay/android-developer/answer/113770)). Nessuna dichiarazione ANSSI lato Play: la pagina non ne parla (**non verificato** che non serva nulla). La Francia resta esclusa (sezione 9), come sull'App Store (ADR 0020, 0022).

## 9. Paesi e regioni

**Test e rilascio → Produzione → Paesi/regioni** (e lo stesso elenco per i test chiusi): tutti i Paesi disponibili **tranne la Francia**, come l'App Store (ADR 0020). Nessun limite di Google sul togliere un solo Paese ([Paesi](https://support.google.com/googleplay/android-developer/answer/7550024)); la distribuzione segue il Paese dell'account Google Play dell'utente, non la sua posizione. Ricordare di ripetere l'esclusione su ogni traccia di test con disponibilità per Paese.
