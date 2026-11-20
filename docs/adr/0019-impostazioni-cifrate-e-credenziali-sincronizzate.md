---
status: Accettato
date: 2026-11-15
---

# Impostazioni cifrate su Drive, con le credenziali degli Account, e chiave trasferita per abbinamento

Decisione del proprietario: un Account sincronizzato non deve più arrivare «da ricollegare» su un altro dispositivo. Le Impostazioni di Postino portano quindi anche le credenziali degli Account (refresh token OAuth di Google e Microsoft, password e server di iCloud e IMAP). Per questo l'intero file su Drive è cifrato, e su Drive non resta nulla in chiaro. La Chiave di sincronizzazione non passa mai da Drive: passa da un dispositivo all'altro con l'Abbinamento, inquadrando un QR come fa WhatsApp oppure digitando o incollando un codice. Questa ADR supera la regola «Token e credenziali non vanno mai nel file» dell'[ADR 0016](0016-sincronizzazione-impostazioni.md). Precisa anche l'[ADR 0001](0001-nessun-backend.md): i token lasciano il dispositivo, ma solo cifrati e solo verso lo spazio Drive dell'utente. Il server resta assente.

## Modello di minaccia

- **Protetto.** Chi ottiene l'accesso all'Account di sincronizzazione, o soltanto alla sua appDataFolder di Drive, vede solo testo cifrato: niente credenziali degli altri Account, niente Impostazioni. La chiave è casuale (256 bit) e non deriva da una password, quindi un attacco offline non può indovinarla. Chi ha accesso a Drive non può nemmeno modificare il file senza che i dispositivi se ne accorgano: AEAD.
- **Non protetto.**
  - Un dispositivo abbinato rubato e sbloccato possiede sia la chiave sia i token. Il rimedio: «Rigenera la chiave» da un altro dispositivo, poi revoca presso i Provider e ricollegamento. Per Gmail si toglie Postino dalle app autorizzate dell'account Google, poi si ricollega l'Account: «Rimuovi» in Postino non revoca più il grant (#353). Per Microsoft si revocano le sessioni dall'account Microsoft. Per iCloud e IMAP si cambia la password specifica per app.
  - Chi controlla Drive può cancellare il file o rimettere una sua copia cifrata più vecchia (rollback). L'AEAD non lo impedisce: è accettato.
  - Un QR o un codice fotografato mentre è sullo schermo, insieme all'accesso a Drive, basta per leggere il file. La mitigazione è nell'Abbinamento, più sotto.

## Cifratura

- **Algoritmo.** AES-256-GCM di `pointycastle` (`GCMBlockCipher(AESEngine())`). `pointycastle` e AES sono già usati per la cache degli allegati, ma lì in modo CTR con HMAC-SHA256 (`attachment_crypto.dart`). GCM è una scelta nuova: un AEAD standard autentica anche l'intestazione con una sola primitiva. Nessuna dipendenza nuova per la cifratura.
- **Nonce e tag.** Nonce di 96 bit da `Random.secure()`, nuovo a ogni scrittura; tag di 128 bit. Un file si scrive al massimo una volta per ciclo, quindi il numero di cifrature con la stessa chiave resta molto lontano dal limite dei nonce casuali di GCM.
- **Busta.** Il file resta `postino-settings.json` ed è un JSON con la sola intestazione in chiaro: `{"postinoEncrypted":1,"keyId":"<16 hex>","nonce":"<base64>","ciphertext":"<base64>"}`.
  - `postinoEncrypted` è la versione del formato.
  - `keyId` è un'impronta della chiave: i primi 8 byte di SHA-256 di un'etichetta fissa seguita dalla chiave. Con una chiave casuale a 256 bit l'impronta non rivela nulla. Si ricava dalla chiave, quindi non va conservata a parte.
  - L'intestazione (versione e `keyId`) entra nei dati autenticati (AAD): non si può cambiare senza invalidare il tag.
- **Contenuto e schema.** Dentro `ciphertext` c'è il documento di oggi, `{"schemaVersion":…,"entries":…}`, con le stesse regole di unione, tombstone e migrazioni dell'ADR 0016. Lo schema passa alla v3: v2→v3 aggiunge la famiglia `credentials/` all'elenco chiuso, senza cambiare la forma delle voci.
- **Versione del formato.** Un file con `postinoEncrypted` maggiore di quella supportata è illeggibile e non si sovrascrive mai, come una `schemaVersion` più alta.
- **Dove sta la cifratura.** Tra `SettingsSync` e la porta `SettingsBackend`: il backend di Drive legge e scrive solo testo cifrato e non vede mai la chiave.
- **Copie doppie.** Oggi `_mergeDuplicates` in `DriveSettingsBackend` decodifica il JSON in chiaro e, se una copia non si legge, lascia stare: non perde nulla, ma con il file cifrato non unirebbe mai. Per questo il backend restituisce tutte le copie e cancella su richiesta quelle di troppo. L'unione delle copie decifrate passa in `SettingsSync`.

## Chiave di sincronizzazione

- **Origine.** La genera il primo dispositivo (32 byte da `Random.secure()`) e da lì passa agli altri solo con l'Abbinamento.
- **Custodia.** Un dispositivo ne tiene una sola: quella del file che legge.
  - Se si sceglie un altro Account di sincronizzazione e lì il file è assente o in chiaro, la chiave si riusa.
  - Se lì il file è cifrato con un'altra chiave, si chiede l'Abbinamento con un dispositivo che sincronizza su quell'Account.
  - Due dispositivi che sincronizzano su Account diversi possono quindi avere chiavi diverse. È corretto: leggono file diversi.
  - Sta nello stesso store e con la stessa accessibilità di `database_key` ([ADR 0017](0017-chiave-database-solo-dispositivo.md)): `first_unlock_this_device`, e nelle release macOS il Data Protection Keychain (`deviceOnlyKeychainFor`).
  - Non segue iCloud Keychain né i backup. Un dispositivo ripristinato da un backup non è abbinato e va abbinato di nuovo: il comportamento è coerente con quello della chiave del database.
- **Dove non va mai.** Mai su Drive, mai nel database, mai nei log o nelle Segnalazioni di un problema: i tipi che la contengono non si stampano (`toString` neutro, come `TokenResponse`).

## Abbinamento

- **Avvio esplicito.** Su un dispositivo abbinato, «Sincronizza su…» → «Abbina un altro dispositivo» mostra un QR e lo stesso contenuto come codice testuale. La schermata si apre solo con questa azione esplicita.
- **Durata e protezioni dello schermo.**
  - La schermata si chiude da sola dopo 2 minuti e quando l'app va in background.
  - Dove la piattaforma lo consente, il contenuto non finisce negli screenshot né nelle registrazioni: `FLAG_SECURE` su Android, `WDA_EXCLUDEFROMCAPTURE` su Windows.
  - Su iOS gli screenshot non si possono impedire: il codice si nasconde mentre lo schermo è registrato o duplicato (`UIScreen.isCaptured`).
  - Su macOS non c'è una protezione affidabile. `NSWindow.sharingType = .none` è un'API legacy che Apple sconsiglia per impedire le catture: si imposta comunque, senza contarci.
  - Su Linux non c'è protezione.
- **Contenuto.** QR e codice contengono solo la versione e la chiave: `P1` seguito dalla chiave in Base32 (RFC 4648, senza padding), mostrato in gruppi di 4 caratteri. Il QR codifica la stessa stringa. Non contengono indirizzi, `keyId` né altro.
- **Il nuovo dispositivo.**
  - Ha già collegato l'Account di sincronizzazione e lo ha scelto in «Sincronizza su…». Quell'Account si collega sempre a mano, perché serve per leggere Drive.
  - Inquadra il QR. Dove non c'è una fotocamera, per esempio su Windows e Linux, digita o incolla il codice.
- **Verifica prima di salvare.** La chiave ricevuta si salva solo dopo che ha decifrato davvero il file remoto attuale: tag valido e `keyId` uguale.
  - Se il file non si legge (offline, errore di Drive), la chiave non si salva e l'utente riprova.
  - Un codice sbagliato è «codice non valido» e non tocca nulla. Lo stesso vale per la chiave di un dispositivo che sincronizza su un altro Account: il messaggio ricorda che i due dispositivi devono usare lo stesso Account di sincronizzazione.
  - Se il file remoto è assente non c'è nulla da abbinare: il dispositivo genera la sua chiave al primo ciclo.

## Stati di un dispositivo

| Stato | Quando | Cosa fa la sincronizzazione | Cosa vede l'utente |
|---|---|---|---|
| **Non abbinato** | Nessuna chiave e file remoto cifrato | Non applica nulla, non scrive nulla, non sovrascrive | In «Sincronizza su…» la richiesta di abbinare il dispositivo |
| **Abbinato** | Chiave con lo stesso `keyId` del file, oppure file assente (senza chiave se ne genera una) | Sincronizza come nell'ADR 0016 e scrive sempre cifrato | Normale |
| **Chiave di sincronizzazione non più valida** | Chiave presente ma file cifrato con un altro `keyId` (dopo una rigenerazione o una corsa) | Come Non abbinato; le voci locali restano da caricare | La richiesta di abbinarlo di nuovo |

Un file con il proprio `keyId` ma con il tag sbagliato è danneggiato o manomesso. È illeggibile e non si sovrascrive. L'utente può scegliere «Rigenera la chiave».

Un file in chiaro si tratta in due modi, a seconda che il dispositivo abbia già una chiave.

- **Con una chiave**, un file in chiaro è un downgrade sospetto: potrebbe averlo messo chi controlla Drive. Il dispositivo non ne applica nessuna voce e lo sovrascrive con la sua copia cifrata. Le voci di un dispositivo vecchio che lo aveva scritto si perdono: è accettato.
- **Senza chiave** è la prima migrazione (sotto). Il dispositivo unisce le voci del file in chiaro come oggi, e solo dopo genera la chiave e scrive il file cifrato. Accetta il file solo con `schemaVersion` al massimo 2, quella delle versioni che scrivevano in chiaro. Non ne applica mai le voci `credentials/`, che un file in chiaro non può legittimamente contenere.

Lo stato si espone accanto all'esito dell'ultimo ciclo di #317.

## Migrazione dal file in chiaro

- **Regola unica.** Si genera una chiave solo se non se ne ha già una e il file remoto è assente o in chiaro. Se il file è già cifrato e non si ha la chiave, non si genera nulla e si chiede l'Abbinamento.
- **Il primo che cifra.** È il primo dispositivo aggiornato che completa un ciclo. Legge il file in chiaro e lo unisce come oggi: in quel momento il file in chiaro vale ancora, con i limiti appena detti (schema al massimo v2, nessuna credenziale). Poi genera la chiave e scrive il file cifrato. Da lì in poi non accetta più file in chiaro.
- **Limite accettato.** Chi controlla Drive può sostituire il file con uno in chiaro prima del primo ciclo di un dispositivo nuovo, non ancora abbinato.
  - Quel dispositivo ne applica le Impostazioni (mai credenziali), genera una sua chiave e riscrive il file.
  - Gli altri finiscono in «Chiave di sincronizzazione non più valida».
  - Se ne accorgono, perché chiedono l'Abbinamento invece di sincronizzare in silenzio.
- **Versioni vecchie (≤1.5.x).**
  - Trovano un JSON senza `entries`, cioè un file illeggibile. Già oggi non lo sovrascrivono (`settings_sync.dart`) e non sincronizzano più nulla, in silenzio: le loro modifiche restano sul dispositivo finché non si aggiornano.
  - L'unione delle copie doppie, in una versione vecchia, lascia stare le copie che non legge.
  - Le note di rilascio devono dire di aggiornare tutti i dispositivi.
- **Due dispositivi che aggiornano insieme.**
  - Tutti e due possono vedere il file in chiaro e generare due chiavi. Il file non ha If-Match, quindi vince l'ultima scrittura.
  - L'altro dispositivo, al ciclo dopo, trova un `keyId` diverso: va in «Chiave di sincronizzazione non più valida» e chiede l'Abbinamento.
  - Non si perde nulla. L'unione include sempre tutte le voci locali, non solo quelle da caricare, quindi dopo l'Abbinamento le sue voci rientrano con last-write-wins.

## Perdita di tutte le chiavi e «Rigenera la chiave»

Un'unica azione, «Rigenera la chiave», in «Sincronizza su…», con una conferma.

- Il dispositivo genera una chiave nuova.
- Se riesce a leggere il file (è abbinato), prima lo unisce.
- Poi lo riscrive cifrato con la chiave nuova.
- Se il file non si legge (chiave persa ovunque, file danneggiato), lo sovrascrive con le sole voci locali. La conferma dice che quello che c'era su Drive e non è su questo dispositivo va perso.
- Gli altri dispositivi passano a «Chiave di sincronizzazione non più valida» e si abbinano di nuovo.

La stessa azione è il rimedio per un dispositivo rubato, insieme alla revoca presso i Provider.

## Credenziali

**Le voci.** Sono separate da `accounts/<accountId>`, così una rotazione del token non entra in conflitto, con last-write-wins, con una modifica di colore o di ordine.

- **iCloud e IMAP:** una voce per Account, `credentials/<accountId>`.
- **Gmail e Microsoft:** una voce per Account e per client OAuth, `credentials/<accountId>/<client>`. Con una sola voce per Account, due dispositivi con client diversi (iOS e Windows per Google) che scrivono insieme si toglierebbero a vicenda il token con last-write-wins. Con una voce per client ciascuno scrive solo la sua.
- **Tombstone:** quello della Rimozione copre tutte le voci con prefisso `credentials/<accountId>`, come le altre voci dell'Account (`accountSettingKeys`).

**Cosa contiene, per Provider.**

- **Gmail e Microsoft.** `{"refresh":"…","scopes":[…]}` nella voce del client.
  - `<client>` è un'impronta dell'ID del client OAuth che ha emesso il token: SHA-256 troncato, mai l'ID in chiaro. Un refresh token vale solo per il client che l'ha emesso, perché Google e Microsoft legano il token alla coppia utente e client.
  - Un dispositivo legge e scrive solo la voce del proprio client.
  - `scopes` sono quelli concessi al token, e per Google contano. Il token dell'Account di sincronizzazione ha anche `drive.appdata` (consenso incrementale, ADR 0016); quello di un collegamento normale no.
  - Un token con meno scope non sostituisce mai, né nella voce né nel Portachiavi, un token dello stesso client con più scope, a meno che il Provider abbia rifiutato quest'ultimo. Così un collegamento senza Drive su un altro dispositivo non toglie Drive all'Account di sincronizzazione.
  - Non si sincronizza mai l'access token: dura un'ora e ogni dispositivo lo ottiene da sé.
- **iCloud e IMAP.** `{"password":"…","imap":{…},"smtp":{…}}`, la stessa forma di `PasswordCredentials`. Con i server nella voce si chiude anche il «possibile ticket futuro» dell'ADR 0016.

**Client diversi.** iOS, macOS e Android usano lo stesso client Google e lo stesso client Microsoft. Windows e Linux usano un altro client Google, «App desktop», e lo stesso client Microsoft.

- Su Windows e Linux un Account Gmail collegato altrove non trova il token del proprio client e resta «da ricollegare» come oggi.
- Una volta ricollegato lì, l'Account ha una voce per ciascuno dei due client.

**Sul dispositivo.** Il segreto resta solo nel Portachiavi/Keystore, come oggi (`oauth:<id>`, `password:<id>`, accessibilità `first_unlock` dello store di `OAuthTokens`).

- Nel Portachiavi stanno anche le voci degli altri client, che questo dispositivo non usa: servono per riscrivere il file senza perderle.
- La riga di `postino_settings` tiene solo `updatedAt`, `deviceId`, `deleted` e un'impronta del valore: il database non contiene mai credenziali.
- Lo scambio tra segreto e impronta avviene ai due bordi del ciclo:
  - **Dopo la decifratura**, il segreto di ogni voce `credentials/` remota va nel Portachiavi (solo se la voce vince l'unione) e nel documento resta la sua impronta. Unione, `applyRemote`, confronto con la copia remota e `markClean` lavorano quindi solo su impronte, come per le altre voci.
  - **Prima della cifratura**, l'impronta torna segreto, letto dal Portachiavi.

**Arrivo.** Una voce `credentials/` vincente si scrive nel Portachiavi sotto il lock degli Account, anche se l'Account non c'è ancora sul dispositivo: la voce `accounts/` può arrivare dopo, e il mirror trova la credenziale. Se è la voce del client di questo dispositivo, diventa la credenziale dell'Account.

- Se l'Account era «da ricollegare» o appena creato dal mirror, torna attivo.
- Il prossimo sync della posta verifica la credenziale. Se il Provider la rifiuta, l'Account torna «da ricollegare» come oggi.

## Rotazione dei token

**Google.** Nella documentazione per le app native la risposta a un refresh contiene un nuovo access token e nessun refresh token: in pratica il refresh token non ruota. Vale finché l'utente non revoca l'accesso o finché il token non scade per una delle cause elencate:

- non usato per sei mesi;
- password cambiata con scope Gmail;
- superato il limite di 100 refresh token per Account Google e client. Oltre il limite i token più vecchi smettono di funzionare.

Condividere un solo token tra i dispositivi tiene lontano proprio quel limite.

**Microsoft.** Il refresh token ruota a ogni uso, ma il vecchio non viene revocato e resta valido fino alla sua scadenza: 90 giorni, 24 ore per le SPA. Il token è legato a utente e client, non al tenant.

**Allineamento.**

- Quando `OAuthAuth.refresh` salva un refresh token diverso (oggi solo Microsoft), aggiorna anche l'impronta e il valore della voce. La voce si carica al ciclo successivo e vince con last-write-wins. È al massimo una scrittura per Account a ogni rinnovo dell'access token, raccolta dal debounce dello scheduler.
- Due dispositivi che ruotano lo stesso token Microsoft insieme non si rompono a vicenda: ogni token della catena resta valido.
- Un dispositivo che riceve un token remoto lo adotta, con la regola degli scope di sopra. Anche il suo, ancora valido, andava bene.
- Un rifiuto definitivo del refresh (`AuthFailure`: `invalid_grant`, HTTP 401, `interaction_required`) non porta subito a «da ricollegare».
  - Prima si rilegge la copia locale della voce, quella dell'ultimo ciclo, senza chiamare Drive dal percorso del token.
  - Se porta per questo client un token diverso da quello rifiutato, lo si adotta e si riprova una volta.
  - Altrimenti l'Account diventa «da ricollegare», e il ricollegamento scrive il token nuovo nella voce per tutti.
  - Vale anche per l'Account di sincronizzazione, perché non serve leggere Drive.

## Rimozione e revoca

**Deciso.** La rimozione resta globale: «Rimuovi» scrive i tombstone delle voci dell'Account su `accounts/` e `credentials/`, e il mirror lo rimuove da ogni dispositivo, credenziali comprese (ADR 0016). Nessuna revoca presso il Provider, né Google né Microsoft (#353).

**Perché niente revoca Google.** La revoca di Google non è per dispositivo ma per grant: toglie a Postino i permessi concessi da quell'utente. iOS, macOS e Android usano lo stesso client OAuth e, con questa ADR, lo stesso refresh token. Una rimozione da una qualunque copia dell'app (anche una build di test, la variante store, un dispositivo non abbinato) scollegava quindi tutti gli altri dispositivi al primo rinnovo, che risponde `invalid_grant`: l'Account diventava «da ricollegare» senza che l'utente l'avesse chiesto lì.

- **Cosa si perde.** Dopo «Rimuovi» il grant resta valido presso Google finché l'utente non toglie Postino dalle app autorizzate dell'account Google, o finché il refresh token resta inutilizzato per 6 mesi. Un dispositivo perso con il token resta in grado di usarlo fino ad allora: il rimedio è quello del modello di minaccia.
- **Conferma di «Rimuovi».** Con la sincronizzazione accesa dice che l'Account viene rimosso da tutti i dispositivi abbinati. Per Gmail dice che Postino resta tra le app autorizzate dell'account Google e che lo si toglie dalle impostazioni dell'account Google.
- **L'Account di sincronizzazione Gmail non è più un'eccezione.** Senza revoca un dispositivo offline mentre il primo carica i tombstone li legge quando torna online, con il suo token ancora valido, e rimuove l'Account come gli altri. La conferma non dice più che lo troverà «da ricollegare». Resta il caso dei tombstone che non arrivano su Drive (dispositivo che rimuove offline o oltre l'attesa): restano da caricare finché non si sceglie un altro Account di sincronizzazione.

**Rinnovo rifiutato (#353).** Solo `invalid_grant` (e `interaction_required` di Microsoft) rendono l'Account «da ricollegare». Un altro rifiuto del token endpoint, per esempio `invalid_client` o `unauthorized_client` con 401, riguarda il client e non il token dell'utente: è un errore imprevisto, va nel log e l'Account resta attivo. Il log errori registra il motivo di ogni passaggio a «da ricollegare» (Provider, status HTTP, codice `error`, se il token era stato adottato dal file sincronizzato) e, al consenso, `refresh_token_expires_in` se il Provider lo manda. Queste righe non portano token, indirizzi né il testo libero di `error_description`: di Microsoft solo il codice `AADSTS…`.

## Norme Google

Nelle norme OAuth 2.0 di Google e nelle buone pratiche non si è trovato nulla sul trasferimento dei token tra dispositivi dello stesso utente: né un divieto né un permesso esplicito. Le norme chiedono di non trasmettere mai i token in chiaro, di custodirli cifrati a riposo e di cancellarli dopo la revoca. Il file cifrato e il Portachiavi rispettano tutte e tre le richieste.

## Fonti

Consultate il 2026-11-15.

- Google, OAuth 2.0 per app native, sezioni sul refresh e su «Token revocation»: https://developers.google.com/identity/protocols/oauth2/native-app
- Google, OAuth 2.0, «Refresh token expiration» (cause di scadenza, limite di 100 refresh token): https://developers.google.com/identity/protocols/oauth2
- Google, norme OAuth 2.0, «Handle user tokens securely»: https://developers.google.com/identity/protocols/oauth2/policies
- Google, buone pratiche OAuth 2.0: https://developers.google.com/identity/protocols/oauth2/resources/best-practices
- Microsoft identity platform, refresh token (rotazione, durata, revoca): https://learn.microsoft.com/en-us/entra/identity-platform/refresh-tokens
- Apple, `NSWindow.SharingType.none`: https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none

## Alternative considerate

- **Cifrare solo le credenziali e lasciare in chiaro il resto.** Indirizzi, Account ed Etichette resterebbero leggibili su Drive. Scartata per decisione del proprietario: niente in chiaro.
- **Chiave derivata da una password (passphrase e KDF).** Andrebbe ricordata a ogni Abbinamento e si può attaccare offline con un dizionario. Scartata a favore di una chiave casuale trasferita per Abbinamento.
- **Chiave su iCloud Keychain.** Copre solo i dispositivi Apple e contraddice l'ADR 0017. Scartata.
- **Una chiave pubblica per dispositivo e la chiave del file avvolta per ciascuno.** Permette di escludere un solo dispositivo senza riabbinare gli altri, ma ha più stato, più formato e più casi limite. Scartata finché «Rigenera la chiave» basta.
- **Credenziali dentro `accounts/<accountId>`.** Una rotazione del token e un cambio di colore entrerebbero in conflitto sulla stessa voce. Scartata.
- **Una sola voce `credentials/<accountId>` con una mappa per client.** Due dispositivi con client diversi che scrivono insieme perderebbero uno dei due token per last-write-wins. Scartata a favore di una voce per client.
- **Riusare CTR + HMAC della cache degli allegati.** Funzionerebbe, ma l'intestazione andrebbe autenticata a mano; GCM lo fa per costruzione, con la stessa libreria. Scartata.
- **Credenziali nella riga di `postino_settings`.** Il database è cifrato, ma oggi le credenziali stanno solo nel Portachiavi, ed è più semplice continuare a garantirlo. Scartata.
- **ChaCha20-Poly1305.** Anche questo è in `pointycastle`. AES è già il cifrario usato nel repo e AES-256-GCM è lo standard più diffuso. Nessuna differenza pratica qui.

## Decisioni sui punti che erano aperti

Il proprietario ha approvato i default proposti:

- **QR in due tempi.** La prima fetta mostra il QR e il codice testuale; il dispositivo nuovo digita o incolla il codice. La lettura del QR con la fotocamera arriva in una fetta successiva. Le librerie per generare il QR (per esempio `qr_flutter`) e per leggerlo (per esempio `mobile_scanner`, con `NSCameraUsageDescription` su iOS e macOS e l'entitlement della fotocamera su macOS) si scelgono e si vagliano con `supermatt:dependency-vetting` al momento dell'implementazione.
- **Rollback del file accettato.** Nessun contatore monotono nel documento: una copia cifrata più vecchia rimessa da chi controlla Drive si accetta.
- **Protezione dello schermo.** Accettata così com'è: su iOS il codice si nasconde solo mentre lo schermo è registrato o duplicato, su macOS e Linux non c'è una protezione affidabile.
- **Nessuna revoca Microsoft alla rimozione.** Come oggi: la catena del token condiviso resta valida fino alla sua scadenza (90 giorni senza uso). Dal #353 nemmeno Google revoca (vedi «Rimozione e revoca»).
- **Schermata di Abbinamento.** Si chiude dopo 2 minuti.

## Precisazioni dall'implementazione (#321, fetta 1)

- **«Rigenera la chiave» e i Postino più nuovi.** Non sovrascrive mai un file scritto da un Postino più nuovo (`postinoEncrypted` o `schemaVersion` più alti): l'utente aggiorna Postino.
- **Quando nasce la chiave.** Si genera solo quando c'è qualcosa da scrivere. La prima chiave si salva prima della scrittura del file. Una chiave rigenerata diventa la chiave del dispositivo solo dopo una scrittura riuscita, così una scrittura fallita lascia il dispositivo con la chiave del file. Fino ad allora resta accanto come chiave in attesa: se la risposta di Drive si perde ma il file è stato scritto, il ciclo successivo trova il file aperto solo da quella e la adotta.
- **Copie doppie sigillate con un'altra chiave.** Un dispositivo con una chiave le scarta. Un dispositivo senza chiave non genera nulla e resta Non abbinato finché non si abbina.
- **Schema v3.** Per ora `credentials/` non entra nell'elenco chiuso: ci entra con le fette che portano le credenziali. Le sue voci restano nel file e non arrivano nel database.

## Precisazioni dall'implementazione (#321, fetta 3: iCloud e IMAP)

- **Elenco chiuso.** Entrano solo `credentials/icloud:…` e `credentials/imap:…`, cioè `credentials/<accountId>` degli Account a password. Le voci per client OAuth (`credentials/<accountId>/<client>`) arrivano con la fetta 4: fino ad allora restano nel file come le voci sconosciute e non arrivano nel database. Lo schema resta v3: la forma delle voci non cambia, e un Postino della fetta 1 conserva le voci `credentials/` che non conosce.
- **Valore.** Il testo del Portachiavi (`password:<accountId>`), identico a quello che scrive `PasswordCredentials`. Una voce remota che non è password e server (la forma di un Postino più nuovo) non si applica e non si stampa, perché l'errore di lettura citerebbe il segreto; torna nel file così com'è.
- **Impronta.** SHA-256 di un'etichetta fissa e del testo del segreto, senza chiave: il database è cifrato con una chiave che resta sul dispositivo (ADR 0017), lo stesso che custodisce il segreto. `SettingsEntry.toString` non stampa mai il valore.
- **Scrittura locale.** Un collegamento con password (anche il ricollegamento) scrive la voce con l'ora attuale anche a sincronizzazione spenta: una password appena verificata vince su una copia più vecchia altrove. Se l'impronta non cambia la voce non si riscrive.
- **Account collegati prima.** A ogni ciclo un Account iCloud o IMAP attivo senza voce la riceve dal Portachiavi come voce scritta prima della sincronizzazione (`updatedAt` 0): una copia di un altro dispositivo vince. Un Portachiavi bloccato salta l'Account e non ferma il resto delle Impostazioni; lo stesso vale prima della cifratura, dove resta la copia del file e la voce resta da caricare.
- **Arrivo.** Sotto l'`AccountsLock`: prima il Portachiavi, poi l'impronta e lo stato dell'Account in una sola transazione (un crash in mezzo riapplica la voce al ciclo dopo). Un Account qui «da ricollegare» torna attivo; il mirror crea attivo un Account la cui credenziale è già nel Portachiavi. Lo stato si cambia solo all'arrivo di una voce che vince, quindi una password rifiutata lascia l'Account «da ricollegare» senza riscritture. Una credenziale il cui Account ha un tombstone nel file non va nel Portachiavi.
- **Prima della cifratura.** Il segreto si prende dalla copia remota o dal Portachiavi, quello che ha l'impronta della voce. Se nessuno dei due ce l'ha (il Portachiavi è cambiato nel frattempo), la voce resta fuori da quella scrittura e resta da caricare.
- **Rimozione.** `accountSettingKeys` scrive anche il tombstone di `credentials/<accountId>` per gli Account a password; un tombstone che arriva cancella la password dal Portachiavi. Un Postino della fetta 1 che rimuove un Account non scrive quel tombstone, e un ricollegamento in corsa con una rimozione può riscrivere la credenziale dopo il tombstone di `accounts/`: in entrambi i casi la credenziale non va nel Portachiavi né si segna come applicata (arriva se l'Account torna), e la scrittura successiva del file la porta come tombstone, così la password non resta su Drive.
- **Limiti accettati.** Se un login IMAP con la password vecchia è in volo quando arriva quella nuova, il suo rifiuto può riportare l'Account «da ricollegare» dopo l'arrivo; la voce non cambia più, quindi resta così finché l'utente non lo ricollega. La rilettura della voce dopo un `AuthFailure` arriva con la fetta 4. Una connessione IMAP già aperta continua con la password e i server con cui si è collegata fino alla riconnessione successiva.

## Precisazioni dall'implementazione (#321, fetta 4: Gmail e Microsoft)

- **Elenco chiuso.** Entrano `credentials/gmail:…/<client>` e `credentials/microsoft:…/<client>`. `<client>` sono i primi 16 caratteri esadecimali di SHA-256 di un'etichetta fissa e dell'ID del client della build. Una voce OAuth senza client non è una forma che Postino scrive: resta nel file e non arriva nel database. Le famiglie restano per prefisso: `usesPassword` su `ProviderKind` non accorcerebbe nulla.
- **Portachiavi.** La voce del client di questo dispositivo sono i suoi token in uso (`oauth:<accountId>`, che ora tengono anche gli scope): nessuna copia a parte. Le voci degli altri client stanno in `oauth:<accountId>/<client>` e non si usano mai qui.
- **Scope.** Vengono dal consenso. I token salvati prima di questa versione non li hanno: li impara una volta il primo rinnovo, dalla risposta del Provider, e da lì li cambia solo un consenso. Così un dispositivo non alterna mai la grafia di un rinnovo (che può non ripetere `openid` ed `email`) con quella di un consenso. Finché non li conosce, il token non va nella voce e una voce remota non lo sostituisce mentre l'Account è attivo. «Meno scope» vuol dire un sottoinsieme stretto degli scope di API: quelli che nominano solo l'utente (`openid`, `email`, `profile`, `offline_access`, `userinfo.*`) e il prefisso di Graph non contano.
- **Regola degli scope.** Una voce remota con meno scope dei token in uso, con l'Account attivo, non entra nel Portachiavi. Al ciclo dopo il dispositivo riscrive la sua voce con l'ora attuale, così il file torna al token con più scope e gli altri lo adottano. Un Account «da ricollegare» adotta qualunque token del suo client: è il caso del rifiuto del Provider.
- **Rotazione.** `OAuthAuth` non scrive nel database. A ogni ciclo la voce del proprio client segue i token in uso: se il refresh token è cambiato (rotazione Microsoft), la voce si scrive con l'ora attuale. Chi adotta un token remoto tiene il suo access token e la sua scadenza: l'arrivo non provoca un rinnovo, quindi nemmeno una rotazione né una nuova scrittura. Il risultato è al massimo una scrittura per Account a ogni rinnovo di un dispositivo, mai un ping-pong.
- **Rilettura su `AuthFailure`.** La copia locale della voce del proprio client sono i token in uso, perché l'arrivo li scrive lì. Al rifiuto del rinnovo `OAuthAuth` rilegge il Portachiavi, mai Drive. Se trova un refresh token diverso da quello rifiutato, riprova una volta; altrimenti l'Account diventa «da ricollegare». Lo stesso vale ora per il login IMAP: chiude il limite della fetta 3 sulle password arrivate durante un login. L'invio SMTP non rilegge.
- **Rimozione.** `tombstoneAccount` scrive il tombstone anche delle voci `credentials/<accountId>/…` presenti qui. Quelle di un client non ancora arrivato diventano tombstone alla scrittura successiva del file, come nella fetta 3. Un tombstone che arriva cancella `oauth:<accountId>/<client>`; i token in uso vanno via con l'Account, quando il mirror lo rimuove, oppure subito se l'Account non è mai arrivato qui.
- **Limiti accettati.**
  - Chi adotta un token remoto non tiene il suo, ancora valido. Se l'Accesso condizionale di Microsoft 365 rifiuta i token usati da un altro dispositivo (Da verificare in QA, punto 1), ricollegare un dispositivo porta l'altro «da ricollegare», e così via. Il rimedio, se la QA lo conferma: tenere il token sostituito e provarlo una volta prima di arrendersi.
  - Un token remoto non adottato per la regola degli scope non torna in gioco se poi il Provider rifiuta quello locale: il dispositivo lo trova solo con la voce successiva, o al ricollegamento.
- **Conferma di «Rimuovi».** Con la sincronizzazione accesa dice che l'Account e il suo accesso vengono rimossi da tutti i dispositivi abbinati. Il testo su Google è cambiato con il #353 (vedi «Rimozione e revoca»).

## Da verificare in QA

1. **Token Microsoft tra piattaforme e Accesso condizionale.** Il client Microsoft è lo stesso su tutte le piattaforme, ma i redirect URI cambiano (schema `msal…` su iOS, Android e macOS; loopback su Windows e Linux). La documentazione dice che il token è legato a utente e client: che un token emesso con un redirect si rinnovi su un altro dispositivo va confermato. Per gli Account Microsoft 365 di lavoro o scuola, l'Accesso condizionale dell'organizzazione (conformità del dispositivo, protezione dei token) può rifiutare un token usato da un altro dispositivo: il comportamento previsto è «da ricollegare» su quel dispositivo.
2. **Revoca Google e client desktop.** Superato dal #353: Postino non revoca più nulla alla rimozione.

## Conseguenze

- Su un dispositivo nuovo l'utente collega solo l'Account di sincronizzazione e abbina il dispositivo; gli altri Account arrivano attivi. Fanno eccezione Gmail su Windows e Linux e i casi da verificare in QA.
- Un dispositivo che resta a una versione ≤1.5.x smette di sincronizzare le Impostazioni appena un altro dispositivo cifra il file.
- Cambiare il client OAuth Google o Microsoft nelle build rende inutili i token della voce per il client vecchio: gli Account tornano «da ricollegare» una volta.
- Il file non è più leggibile a mano da Drive per il debug.
