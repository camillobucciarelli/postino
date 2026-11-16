# Dichiarazioni per la Play Console

Risposte per la pagina **Monitora e migliora → Norme e programmi → Contenuti dell'app** (in inglese *Policy → App content*) e per i permessi, della variante Android «store» (#345). Requisiti verificati sulle pagine di Google il 16/11/2026; nessuna pagina mostra una data di ultima modifica. Ciò che non ho trovato scritto su una pagina ufficiale è segnato **non verificato**.

## 1. Norme sulla privacy

URL: https://postino.camillobucciarelli.dev/privacy.html. Google lo chiede **anche se l'app non raccoglie dati**, pubblico, in HTTPS, non PDF, e lo vuole anche dentro l'app (c'è: Impostazioni → Informativa sulla privacy) ([preparare l'app per la revisione](https://support.google.com/googleplay/android-developer/answer/9859455), [Sicurezza dei dati](https://support.google.com/googleplay/android-developer/answer/10787469)).

**Da aggiornare prima dell'invio** (il sito è fuori da #345, lo fa il titolare): l'informativa del 15/11/2026 dice che il file su Drive non contiene «mai posta, password o token», ma con #321 (ADR 0019, fette 3 e 4 unite) contiene anche le credenziali degli Account, cifrate con una chiave che resta sui dispositivi. Dice anche che Android controlla gli aggiornamenti sul sito: la variante Play non lo fa (fetta 1 di #345). Infine non nomina la fotocamera (usata solo per «Inquadra il QR», l'immagine non esce dal dispositivo) né ML Kit di Google, che allo scanner manda a Google dati diagnostici e identificatori (sezione 2).

## 2. Sicurezza dei dati (Data safety)

Fonte: [Sicurezza dei dati](https://support.google.com/googleplay/android-developer/answer/10787469), letta il 16/11/2026. Le regole di Google sono diverse da quelle di Apple, quindi qui la risposta **non** è quella di [app-privacy.md](app-privacy.md) («Dati non raccolti»):

- Google chiama «raccolta» ogni trasmissione fuori dal dispositivo, anche verso server di terzi e anche da un SDK. Apple invece guarda a chi può accedere al dato.
- L'esenzione per le azioni avviate dall'utente vale solo per la **condivisione**, non per la raccolta.
- Fuori dalla raccolta restano solo l'elaborazione sul dispositivo e i dati cifrati end-to-end; il caricamento diretto sul cloud dell'utente non va dichiarato se l'app non accede al dato.

Quindi Postino dichiara quello che trasmette verso i Provider, il log della Segnalazione di un problema e quello che manda a Google lo scanner del QR (ML Kit). È la scelta prudente: dichiarare un dato in più non viola le regole, ometterlo sì. **Non verificato** come Google tratti i client email che parlano solo con i Provider dell'utente: la pagina non nomina il caso.

### Risposte

| Domanda | Risposta |
|---|---|
| La tua app raccoglie o condivide uno dei tipi di dati utente richiesti? | **Sì** |
| Tutti i dati raccolti sono criptati in transito? | **Sì**: IMAP e SMTP solo con SSL o STARTTLS (`ServerSecurity` in `lib/core/domain/mail_servers.dart`), Gmail, Graph e Drive in HTTPS, ML Kit in HTTPS |
| Fornisci agli utenti un modo per richiedere l'eliminazione dei dati? | **Sì**: la posta si elimina dall'app sul Provider, «Rimuovi Account» cancella la copia locale, e i dati della Segnalazione si cancellano scrivendo a `camillo@bucciarelli.dev` (informativa) |

| Tipo di dato | Raccolto | Condiviso | Temporaneo | Obbligatorio o facoltativo | Finalità | Perché |
|---|---|---|---|---|---|---|
| Informazioni personali → **Indirizzo email** | Sì | No | No | Obbligatorio | Funzionalità dell'app | L'indirizzo dell'Account va al suo Provider; è anche il mittente della Segnalazione |
| Messaggi → **Email** | Sì | No | No | Obbligatorio | Funzionalità dell'app | Posta letta, inviata e sincronizzata con il Provider; il log della Segnalazione può contenere oggetti e indirizzi |
| File e documenti → **File e documenti** | Sì | No | No | Facoltativo | Funzionalità dell'app | Allegati che l'utente sceglie di inviare |
| Informazioni e prestazioni dell'app → **Log degli arresti anomali** | Sì | No | No | Facoltativo | Funzionalità dell'app | Log nella Segnalazione, solo se l'utente la invia |
| Informazioni e prestazioni dell'app → **Altri dati diagnostici** | Sì | No | No | Facoltativo | Analisi, Funzionalità dell'app | Segnalazione; metriche e codici d'errore di ML Kit quando l'utente inquadra un QR |
| ID dispositivo o altri ID → **ID dispositivo o altri ID** | Sì | No | No | Facoltativo | Analisi | ML Kit, solo quando l'utente inquadra un QR |

**Condiviso: No** per tutti. I trasferimenti al Provider scelto dall'utente sono azioni avviate dall'utente (non sono «condivisione» per Google) e ML Kit dichiara di non passare i dati a terzi ([informativa ML Kit](https://developers.google.com/ml-kit/android-data-disclosure): dati del dispositivo e dell'app, identificatori, metriche e codici d'errore, «for diagnostics and usage analytics», in HTTPS). **Facoltativo** perché lo scanner e la Segnalazione partono solo se l'utente li usa. **Non verificato** quale riga «identificatori» di ML Kit valga per lo scanner unbundled (la pagina distingue funzioni *thin* e *bundled* senza dire dove sta il barcode): dichiararla comunque.

### Cosa resta fuori, e perché

| Dato che esce dal dispositivo | Dove va | Perché non va dichiarato |
|---|---|---|
| Impostazioni e credenziali sincronizzate | Cartella `appDataFolder` del Google Drive dell'utente, file AES-256-GCM | Cifrato end-to-end con la Chiave di sincronizzazione, che resta sui dispositivi dell'utente (ADR 0019): illeggibile per chiunque altro, sviluppatore compreso. Google esclude i dati cifrati end-to-end. |
| Password IMAP e token OAuth | Al Provider, per l'accesso | Credenziali di accesso al servizio dell'utente; non sono un tipo di dato del modulo (**non verificato**: nessuna voce «credenziali» nell'elenco di Google). |
| Testo dei messaggi per l'Etichettatura automatica | Nessun luogo | Elaborato solo sul dispositivo (ADR 0015). |
| Download del modello | Richiesta a `huggingface.co` | Non porta dati dell'utente (URL fisso, verifica SHA-256). |
| Ricerca della configurazione IMAP | Autoconfig del dominio dell'utente, DNS di Google, database di Thunderbird | Il dominio e l'indirizzo dell'Account, già dichiarato sopra. |
| Immagine della fotocamera («Inquadra il QR») | Nessun luogo | Il QR si decodifica sul dispositivo; ML Kit manda solo i dati della tabella sopra. |
| Controllo degli aggiornamenti dal sito | Nessun luogo nella variante Play | Spento nella variante «store» (fetta 1 di #345). Se la fetta 1 non lo spegnesse, il punto va rivisto. |

**Differenza con l'App Store, da sapere.** Su Apple la stessa app è dichiarata «Dati non raccolti» perché Apple non conta come raccolta il dato che lo sviluppatore non può leggere, e la Segnalazione usa l'esclusione facoltativa di Apple. Le due risposte non si contraddicono: rispondono a definizioni diverse. ML Kit è solo su Android: `ios/Podfile.lock` non contiene pod MLKit (`mobile_scanner` 7 su iOS usa il framework Vision di Apple, **non verificato** nel codice del plugin).

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
3. Tocco sull'interruttore: Postino apre la schermata di sistema dell'ottimizzazione batteria; scegliere Postino e impostarlo su «Non ottimizzare» / senza limiti, poi tornare in Postino. Compare la notifica fissa **«Postino is listening»**: abbassare la tendina per mostrarla (15–20 s). Registrare sulla build **`store`** scaricata da Play (test interno): l'APK del sito mostra invece il dialogo di sistema a un tocco, che la variante Play non ha.
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
