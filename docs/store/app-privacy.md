# App Privacy e questionario sull'età

Risposte per la sezione **App Privacy** (etichetta nutrizionale) e per il **questionario sull'età** di App Store Connect. Fonti: l'[informativa](https://postino.camillobucciarelli.dev/privacy.html) (aggiornata il 14/11/2026), ADR 0001, 0003, 0007, 0013, 0015, 0016, e il codice. `PrivacyInfo.xcprivacy` non esiste ancora: lo porta #323 (iOS) e #325 (macOS); le risposte sotto devono coincidere con quel file, da controllare quando le due PR sono unite.

## 1. Risposta d'insieme

**Data Not Collected** («Non raccogliamo dati da quest'app»). **Tracking: No.** Nessun dominio di tracciamento, nessuna richiesta ATT (`NSUserTrackingUsageDescription` assente in `Info.plist`).

Perché: Apple chiama «raccolta» il dato che lascia il dispositivo in modo che lo sviluppatore o un partner possano accedervi per più del tempo necessario a servire la richiesta in tempo reale. Postino non ha backend (ADR 0001): posta, credenziali, chiavi e log restano sul dispositivo; le uniche connessioni vanno ai Provider che l'utente stesso collega, a Drive dell'utente e al download del modello. Nessun SDK di analytics, pubblicità o crash reporting nelle dipendenze (`pubspec.yaml`); l'Observability (ADR 0013) è prevista «dalla v2» e **non è nel codice**.

## 2. Voce per voce (le categorie di Apple)

| Categoria Apple | Risposta | Motivo |
|---|---|---|
| Contact Info (nome, email, telefono, indirizzo, altro) | Non raccolta | L'indirizzo dell'Account e i Contatti restano sul dispositivo e vanno solo al Provider. |
| Health & Fitness | Non raccolta | Non trattata. |
| Financial Info | Non raccolta | Nessun pagamento né acquisto in-app. |
| Location | Non raccolta | Nessun permesso di posizione. |
| Sensitive Info | Non raccolta | Non trattata. |
| Contacts | Non raccolta | I Contatti si ricavano dagli indirizzi visti nella posta o dalla rubrica dell'Account sul Provider; non vengono inviati allo sviluppatore. Nessun accesso alla rubrica del sistema (nessuna `NSContactsUsageDescription`). |
| User Content (email, messaggi, foto, file, audio, altro) | Non raccolta | La posta e gli allegati vanno solo tra dispositivo e Provider. Il testo dei messaggi alimenta l'IA sul dispositivo e non esce (ADR 0015). |
| Browsing History | Non raccolta | I link si aprono nel browser di sistema. |
| Search History | Non raccolta | La Ricerca gira sul database locale e sul Provider dell'Account. |
| Identifiers (User ID, Device ID) | Non raccolta | Nessun account Postino, nessun IDFA/IDFV inviato. |
| Purchases | Non raccolta | Nessun acquisto. |
| Usage Data (interazione con il prodotto, pubblicità, altro) | Non raccolta | Nessuna analytics. |
| Diagnostics (crash, prestazioni, altro) | Non raccolta | Il log degli errori è cifrato e resta sul dispositivo; non esce da solo (vedi eccezione sotto). |
| Surrounding Environment, Body, Other Data | Non raccolta | Non trattati. |

Domande di contorno: **Tracking** No. **Collegamento all'identità dell'utente** non applicabile (nessun dato raccolto).

## 3. Eccezioni da conoscere

1. **Segnalazione di un problema.** L'utente può mandare allo sviluppatore un'email con il log degli errori (può contenere oggetti e indirizzi). È la sola via con cui lo sviluppatore riceve dati. Resta fuori dall'etichetta con l'**esclusione facoltativa** di Apple, perché tutte le sue condizioni valgono: non serve al tracciamento, non è condivisa, avviene di rado (solo se l'utente la sceglie), non è parte della funzione principale dell'app, è spiegata all'utente prima (il testo della bozza e l'informativa) e l'utente decide ogni volta se inviarla, dopo averla riletta. **Decisione del titolare:** se preferisce non appoggiarsi all'esclusione, dichiarare *Diagnostics → Other Diagnostic Data* e *User Content → Other User Content*, «App Functionality», **linked to the user** (la Segnalazione parte dall'indirizzo dell'Account e lo sviluppatore la conserva: aggiungere anche *Contact Info → Email Address* e *User Content → Customer Support*), «No tracking».
2. **Aggiornamenti.** Su iOS (fino a #323) l'app legge `ios/latest/version.json` da `postino.camillobucciarelli.dev` al massimo una volta al giorno: la richiesta è uguale per tutti e non porta identificativi, ma Cloudflare vede l'indirizzo IP come per ogni richiesta web (informativa, «Sito e download»). L'informativa dice che Cloudflare lo conserva secondo la sua conservazione standard: non è dimostrato che l'eccezione «solo per servire la richiesta» si applichi. **Da verificare dal titolare** prima di scegliere «Data Not Collected»; se non si applica, dichiarare *Identifiers/Other Data → IP address* per «App Functionality». Resta da confermare anche quando #323 cambia il banner di aggiornamento verso l'App Store (se il controllo sul sito sparisce, il punto cade).
3. **Download del modello da Hugging Face** e **ricerca della configurazione IMAP** (autoconfig del dominio, DNS di Google, database Thunderbird): sono richieste a terzi, fatte dal dispositivo e non dallo sviluppatore; non portano posta né password (l'indirizzo email intero va all'`autoconfig.` del dominio dell'utente, via HTTPS). Non sono dati raccolti dallo sviluppatore.
4. **Google (Drive `appdata`, Gmail) e Microsoft (Graph).** Il dato va al Provider scelto dall'utente, con il consenso del Provider; lo sviluppatore non lo riceve. Il Limited Use di Google è dichiarato in informativa.

## 4. Coerenza con `PrivacyInfo.xcprivacy` (#323, #325)

Il manifest deve dire: `NSPrivacyTracking` = false; `NSPrivacyTrackingDomains` vuoto; `NSPrivacyCollectedDataTypes` vuoto; `NSPrivacyAccessedAPITypes` con le sole required-reason API usate da app e plugin. Ogni cambiamento qui sopra (per esempio la scelta sulla Segnalazione) va riportato in quel file e viceversa.

## 5. Questionario sull'età

Domande del questionario di App Store Connect (2025+). Risposte proposte, ricavate dal comportamento dell'app.

| Domanda | Risposta | Motivo |
|---|---|---|
| Violenza (cartoon/fantasy, realistica, armi, ecc.) | Nessuna | Postino non produce contenuto: mostra la posta dell'utente. |
| Contenuti sessuali o nudità, linguaggio volgare, horror, temi a tema alcol/tabacco/droghe, riferimenti medici, gioco d'azzardo simulato | Nessuno | Idem. |
| Gioco d'azzardo reale, concorsi/lotterie | No | Non presenti. |
| Controlli parentali | No | Non presenti. |
| Verifica dell'età | No | Non presente. |
| Accesso web senza restrizioni | No | I link si aprono nel browser di sistema, con avviso se il testo mostra un indirizzo diverso; «Vedi originale» usa una WebView con JavaScript disabilitato e CSP (ADR 0007), non un browser. |
| Contenuti generati dagli utenti | No | Nessuna piattaforma Postino: i messaggi viaggiano tra l'utente e il suo Provider. |
| Messaggistica e chat | **Sì** | È un client email: l'utente può scrivere a chiunque. Apple può trattarla come messaggistica; controllare la fascia che ne risulta. |

Fascia attesa: **4+** (la tabella di Apple ammette messaggistica a 4+). Non verificata: App Store Connect calcola la fascia al salvataggio. Nessun blocco per i Paesi (Brasile, Australia, ecc.) è atteso, ma si ricontrolla dopo il salvataggio.
