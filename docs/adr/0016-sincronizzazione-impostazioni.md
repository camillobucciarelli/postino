---
status: Accettato
date: 2026-11-05
---

# Sincronizzazione delle Impostazioni di Postino su un Account scelto

Le Impostazioni di Postino si sincronizzano in un solo file, `postino-settings.json`, nella appDataFolder di Google Drive dell'Account che l'utente sceglie nelle Impostazioni alla voce "Sincronizza su…": l'**Account di sincronizzazione**. La scelta è un'Impostazione del dispositivo (`settings_sync_account` in `device_settings`); senza una scelta la sincronizzazione è spenta e le Impostazioni restano locali. Lo scope `drive.appdata` si chiede con un consenso incrementale (`include_granted_scopes=true`) solo per quell'Account.

**Il file.** `{"schemaVersion":1,"entries":{"<key>":{"value":<JSON>|null,"updatedAt":ms,"deviceId":"…","deleted":bool}}}`, una voce per chiave di `postino_settings`. Token e credenziali non vanno mai nel file.

- Le migrazioni dello schema vanno solo in avanti e si applicano in lettura, con una catena vN→vN+1: una versione nuova è una funzione in più. Oggi c'è solo la v1.
- Un file con `schemaVersion` maggiore di quella supportata si legge (le voci che si decodificano) ma non si sovrascrive mai: le voci locali restano da caricare finché l'app non si aggiorna.
- Un file che non si riesce a leggere non si sovrascrive: tale è anche un file senza `entries` o con `schemaVersion` minore di 1.
- Se due dispositivi creano il file insieme, la ricerca per `createdTime` trova le copie: si uniscono come sotto nella più vecchia e le altre si cancellano.

**Unione.** Per ogni chiave vince `updatedAt` maggiore, a parità il `deviceId` maggiore (un id casuale stabile del dispositivo, in `device_settings`). A parità esatta di entrambi (le voci migrate con valori diversi su due dispositivi hanno `updatedAt` 0 e `deviceId` vuoto) vince la copia remota: il secondo dispositivo adotta il valore già caricato dal primo e smette di ricaricare. I tombstone partecipano come le altre voci: scrivere null non cancella la riga ma lascia un tombstone, così una copia più vecchia non resuscita la voce. Una scrittura locale non va mai indietro nel tempo rispetto alla copia che sostituisce. Le voci scritte prima della sincronizzazione (migrazione allo schema 16 del database) hanno `updatedAt` 0 e restano da caricare: entrano nel file solo se manca la voce, e non sovrascrivono mai una copia già sincronizzata da un altro dispositivo.

**Elenco chiuso.** Entrano nel file solo le voci con un prefisso dell'elenco (oggi `auto_labels/<accountId>` e `swipe/`: `swipe/left` e `swipe/right`, l'Azione di ciascuna direzione di scorrimento, uguale per tutti gli Account e quindi senza tombstone alla rimozione di un Account); le Impostazioni del dispositivo mai. Le voci fuori elenco scritte da un Postino più nuovo restano nel file ma non si applicano in locale.

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

- Rimuovere un Account scrive i tombstone delle sue voci (`tombstoneAccount`); la UI arriva con il ticket della rimozione degli Account.
- Un ticket futuro aggiunge gli Account (indirizzo, Provider, colore, ordine) alle voci sincronizzate.
- Last-write-wins per voce: modifiche concorrenti a due Etichette dello stesso Account sono una sola voce, e vince l'ultima.
