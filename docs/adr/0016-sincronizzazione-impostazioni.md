---
status: Accettato
date: 2026-11-05
---

# Sincronizzazione delle Impostazioni di Postino su un Account scelto

Le Impostazioni di Postino si sincronizzano in un solo file, `postino-settings.json`, nella appDataFolder di Google Drive dell'Account che l'utente sceglie nelle Impostazioni alla voce "Sincronizza su…": l'**Account di sincronizzazione**. La scelta è un'Impostazione del dispositivo (`settings_sync_account` in `device_settings`); senza una scelta la sincronizzazione è spenta e le Impostazioni restano locali. Lo scope `drive.appdata` si chiede con un consenso incrementale (`include_granted_scopes=true`) solo per quell'Account.

**Il file.** `{"schemaVersion":2,"entries":{"<key>":{"value":<JSON>|null,"updatedAt":ms,"deviceId":"…","deleted":bool}}}`, una voce per chiave di `postino_settings`. Token e credenziali non vanno mai nel file.

- Le migrazioni dello schema vanno solo in avanti e si applicano in lettura, con una catena vN→vN+1: una versione nuova è una funzione in più. Oggi lo schema è la v2: v1→v2 aggiunge la famiglia `accounts/` all'elenco chiuso e non cambia la forma delle voci, quindi è l'identità.
- Un file con `schemaVersion` maggiore di quella supportata si legge (le voci che si decodificano) ma non si sovrascrive mai: le voci locali restano da caricare finché l'app non si aggiorna.
- Un file che non si riesce a leggere non si sovrascrive: tale è anche un file senza `entries` o con `schemaVersion` minore di 1.
- Se due dispositivi creano il file insieme, la ricerca per `createdTime` trova le copie: si uniscono come sotto nella più vecchia e le altre si cancellano.

**Unione.** Per ogni chiave vince `updatedAt` maggiore, a parità il `deviceId` maggiore (un id casuale stabile del dispositivo, in `device_settings`). A parità esatta di entrambi (le voci migrate con valori diversi su due dispositivi hanno `updatedAt` 0 e `deviceId` vuoto) vince la copia remota: il secondo dispositivo adotta il valore già caricato dal primo e smette di ricaricare. I tombstone partecipano come le altre voci: scrivere null non cancella la riga ma lascia un tombstone, così una copia più vecchia non resuscita la voce. Una scrittura locale non va mai indietro nel tempo rispetto alla copia che sostituisce. Le voci scritte prima della sincronizzazione (migrazione allo schema 16 del database) hanno `updatedAt` 0 e restano da caricare: entrano nel file solo se manca la voce, e non sovrascrivono mai una copia già sincronizzata da un altro dispositivo.

**Elenco chiuso.** Entrano nel file solo le voci con un prefisso dell'elenco (oggi `auto_labels/<accountId>`, `accounts/<accountId>` e `swipe/`: `swipe/left` e `swipe/right`, l'Azione di ciascuna direzione di scorrimento, uguale per tutti gli Account e quindi senza tombstone alla rimozione di un Account); le Impostazioni del dispositivo mai. Le voci fuori elenco scritte da un Postino più nuovo restano nel file ma non si applicano in locale.

**Account collegati.** Ogni Account è la voce `accounts/<accountId>` con valore `{"address":"…","provider":"gmail","color":<indice della palette>,"position":<int>}`; mai lo stato, mai credenziali o token. La lettura è tollerante: una voce malformata o con un Provider sconosciuto si ignora, i campi sconosciuti pure.

- La voce è la fonte di verità per indirizzo, Provider, colore e ordine; la tabella `accounts` ne è lo specchio locale e tiene in più lo stato (`attivo`/`daRicollegare`), che resta solo sul dispositivo.
- Locale → voce: collegare un Account nuovo, o un Account il cui colore o posizione non coincidono con la voce, la scrive insieme alla riga, in una transazione. Un ricollegamento con valori identici non la riscrive, così il suo `updatedAt` non avanza.
- Un Account nuovo, senza voce locale, collegato a sincronizzazione spenta (l'onboarding viene prima di "Sincronizza su…") scrive la voce come le voci pre-sync: `updatedAt` 0, `deviceId` vuoto, da caricare. Così la copia già sincronizzata da un altro dispositivo vince sui colori e sulle posizioni di default. A sincronizzazione accesa la voce porta l'ora attuale, così un tombstone più vecchio non rimuove un Account appena ricollegato apposta. Limite noto: un Account rimosso altrove e collegato qui a sincronizzazione spenta viene rimosso dal tombstone quando la sincronizzazione si accende; basta ricollegarlo.
- Una voce il cui id non è `<provider>:<indirizzo>` (indirizzo normalizzato come al collegamento) è incoerente e si ignora.
- Voce → locale: `AccountsSettingsMirror` osserva le voci `accounts/*` (tombstone compresi). Una voce viva per un Account assente crea l'Account "da collegare": `daRicollegare`, senza credenziali, già con colore e ordine; lo SyncEngine lo salta e il banner "Accedi" lo collega con `connectGmail(loginHint)`, che per l'id deterministico (`gmail:<indirizzo>`) aggiorna la stessa riga senza duplicati. Una voce viva per un Account presente aggiorna indirizzo, colore e posizione e preserva lo stato. Un Account locale senza voce non si tocca. Una voce per una casella che qui è già collegata con un altro Provider (stesso indirizzo, altro id) non crea un secondo Account: l'Account dell'altro dispositivo resta invisibile qui finché uno dei due non viene rimosso.
- Gli Account iCloud e IMAP (#162) seguono le stesse regole, con id `icloud:<indirizzo>` e `imap:<indirizzo>`. I loro server non entrano nella voce (stanno nel keychain con la password): arrivano su un altro dispositivo da collegare senza server, e il ricollegamento li trova con il preset (iCloud), la discovery o il form. Mettere i server nella voce è un possibile ticket futuro.
- Un tombstone rimuove l'Account dal dispositivo: prima le credenziali di qualunque Provider dal Keychain/Keystore (token OAuth di Gmail, password e server di iCloud e IMAP), poi, in una transazione, la riga e i dati di posta locali (ogni tabella con `account_id`); il suo adapter si dimentica e la sua sessione IMAP si chiude. Un sync della posta ancora in corso non riscrive nulla per un Account che non c'è più, né adotta una sua Bozza. Rimozione e collegamento di un Account (credenziali e riga) passano da un unico lock, così una rimozione non cancella le credenziali appena scritte da un ricollegamento. Per l'Account di sincronizzazione la rimozione locale aspetta che il tombstone sia caricato (la voce torna pulita): caricarlo richiede proprio le sue credenziali. Non aspetta se l'Account è `daRicollegare`, perché non potrebbe caricarlo: si rimuove subito e il tombstone resta da caricare finché non si sceglie un altro Account di sincronizzazione. Scegliere un altro Account, o nessuno, sblocca anche una rimozione in attesa, e così l'Account che diventa `daRicollegare` mentre aspetta (un AuthFailure della posta). Poi `settings_sync_account` si azzera e la sincronizzazione si spegne invece di fallire in silenzio. Un passaggio fallito (Portachiavi bloccato) si ritenta da solo, con un ritardo che raddoppia fino a un tetto.
- Un Account nuovo prende la posizione massima + 1; l'elenco si ordina per posizione e poi per id, così l'ordine resta stabile anche con posizioni uguali (due Account aggiunti insieme su due dispositivi).
- Gli Account già presenti all'aggiornamento entrano con la migrazione 20 del database come le voci pre-sync: `updatedAt` 0, `deviceId` vuoto, da caricare; non sovrascrivono mai una copia già sincronizzata.

**Scheduler.** `SettingsSync` è separato dal motore della posta ([ADR 0008](0008-motore-di-sincronizzazione.md)). Un ciclo parte all'avvio, quando cambia l'Account di sincronizzazione, quando torna la rete, ogni 60 s e qualche secondo dopo l'ultima scrittura locale; mai due cicli insieme. Il ciclo legge il file, unisce le due copie, applica in locale le voci remote vincenti (già caricate), scrive il file se è cambiato e la versione lo permette, poi segna come caricate le voci locali non riscritte nel frattempo. Offline o con un errore le voci restano da caricare e si riprova al ciclo dopo.

**Errori di Drive.** Un 403 di Drive per lo scope mancante (`insufficientPermissions`, `ACCESS_TOKEN_SCOPE_INSUFFICIENT`) è `DriveScopeFailure`, non `AuthFailure`: la posta dell'Account funziona e l'Account non diventa mai Da ricollegare per colpa di Drive. Gli altri 403 sono errori imprevisti. Token e richiesta hanno un timeout unico, così un refresh bloccato non ferma lo scheduler, e la chiusura dell'app aspetta il ciclo in corso solo per pochi secondi. Lo scheduler non tocca mai lo stato degli Account.

**Porta `SettingsBackend`.** Il file si legge e si scrive tramite una porta del dominio (`read`/`write` del JSON). Oggi c'è solo Drive; l'export/import come file e altri Provider useranno la stessa porta, scelta in un'unica factory.

## Rapporto con le altre ADR

- [ADR 0004](0004-impostazioni-su-drive.md): questa ADR ne precisa il "come". Il file non sta nello spazio Google di ogni Account, ma in quello del solo Account di sincronizzazione scelto dall'utente.
- [ADR 0015](0015-ia-sul-dispositivo.md): la configurazione delle Etichette automatiche (`auto_labels/<accountId>`) è la prima voce dell'elenco chiuso.

## Alternative considerate

- **Un file per ogni Account Google**: più copie da tenere d'accordo, e un utente con più Account Google non saprebbe dove stanno le sue Impostazioni. Scartata.
- **Un file per voce**: più richieste a Drive per ciclo, nessun vantaggio con poche voci. Scartata.
- **Concorrenza ottimistica (If-Match) sul file**: due dispositivi che scrivono insieme possono togliersi voci a vicenda, ma il ciclo successivo di ciascuno le riscrive, perché l'unione include sempre tutte le voci locali. Rimandata finché non serve.

## Conseguenze

- Rimuovere un Account scrive i tombstone delle sue voci (`tombstoneAccount`) e il mirror lo toglie da ogni dispositivo, credenziali comprese; la UI arriva con il ticket della rimozione degli Account.
- Last-write-wins per voce: modifiche concorrenti a due Etichette dello stesso Account sono una sola voce, e vince l'ultima.
