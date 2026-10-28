# Invio della posta per Provider

Ricerca per il ticket #3 (mappa #1). Data: 2026-10-28. Fonti consultate in quella data; le versioni dei pacchetti sono quelle pubblicate su pub.dev a quella data.

Legenda: **[F]** fatto osservato in una fonte primaria, **[I]** inferenza, **[R]** raccomandazione.

## Domanda

Per Gmail e Microsoft si invia via API (Gmail API `send`, Graph `sendMail`) o via SMTP con OAuth? Per iCloud e gli altri IMAP quali server SMTP e quale autenticazione? Cosa cambia per Bozze e Inviati in ciascun caso? Con attenzione a pacchetti Flutter/Dart, scope OAuth (ADR 0008), limiti sugli allegati e coda di azioni offline (ADR 0003, 0008).

## Risposta breve

- **Gmail → Gmail API** (`users.messages.send` / `users.drafts.*`) con il MIME grezzo costruito da noi. Nessuno scope nuovo: `https://mail.google.com/` (ADR 0008) copre già tutto. Limite 35 MB sul messaggio codificato. Inviati e Bozze sono gestiti dal Provider.
- **Microsoft → Graph** `POST /me/sendMail` in formato MIME (base64) per i messaggi normali. `Mail.Send` e `Mail.ReadWrite` sono già negli scope. Graph salva da solo in Posta inviata. Per gli allegati oltre ~3-4 MB serve il percorso bozza + upload session + `send`, che però non accetta MIME grezzo: per i messaggi firmati o cifrati (ADR 0012) di grandi dimensioni resta un punto aperto (vedi sotto).
- **iCloud → SMTP** `smtp.mail.me.com:587` (STARTTLS), utente = indirizzo completo, **password per app** (Apple non offre OAuth ai client di terze parti). Stessa password per app usata per IMAP.
- **Altri IMAP → SMTP** via `enough_mail` (PLAIN/LOGIN o XOAUTH2 dove il Provider lo supporta), impostazioni trovate con autodiscovery RFC 6186 / database di `enough_mail`. Dopo l'invio, **APPEND** del messaggio nella cartella Inviati da parte del client; Bozze = APPEND in Bozze con flag `\Draft`.
- **Coda offline**: l'invio non è idempotente. Si genera `Message-ID` sul dispositivo prima di accodare e, prima di ritentare, si controlla se quel `Message-ID` è già in Inviati.

## 1. Gmail

### Fatti

- `users.messages.send` accetta un messaggio RFC 2822 codificato base64url nel campo `raw`, oppure un upload multimediale su `POST https://gmail.googleapis.com/upload/gmail/v1/users/{userId}/messages/send`. [F] — https://developers.google.com/workspace/gmail/api/guides/sending, https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/send
- Scope accettati da `messages.send`: `https://mail.google.com/`, `gmail.modify`, `gmail.compose`, `gmail.send`. [F] — stessa pagina di riferimento e documento di discovery `https://gmail.googleapis.com/$discovery/rest?version=v1`
- Dimensione massima dell'upload (`mediaUpload.maxSize`) per `messages.send`, `drafts.create`, `drafts.update`, `drafts.send`: **36 700 160 byte (35 MB)**; per `messages.insert`/`import`: 150 MB. [F] — documento di discovery, letto il 2026-10-28
- Per mettere un messaggio in un thread esistente servono `threadId` sul Message, `References`/`In-Reply-To` conformi a RFC 2822 e `Subject` uguale. [F] — descrizione del campo `Message.threadId` nel documento di discovery
- Bozze: `drafts.create` / `drafts.update` con `raw`; l'update distrugge e sostituisce il messaggio (cambia l'id del messaggio, resta stabile l'id della bozza); `drafts.send` elimina la bozza e crea un nuovo messaggio con etichetta `SENT`. Le bozze possono avere solo l'etichetta `DRAFT`. [F] — https://developers.google.com/workspace/gmail/api/guides/drafts
- Anche SMTP è possibile: `smtp.gmail.com` 465 (SSL) o 587 (STARTTLS), con SASL XOAUTH2. [F] — https://developers.google.com/workspace/gmail/imap/imap-smtp
- Quando si invia via SMTP Gmail salva da solo una copia in "Posta inviata"; un client che fa anche APPEND crea un duplicato. [F, fonte secondaria: thread di bug di client terzi che riportano la spiegazione di Google] — https://bugzilla.gnome.org/show_bug.cgi?id=599230, https://www.mysysadmintips.com/gmail-imap-via-outlook-duplicated-sent-emails/

### Inferenze

- Un messaggio inviato con `messages.send` riceve l'etichetta `SENT` e compare nella history, quindi il motore di sync (ADR 0008) lo vede senza lavoro aggiuntivo. La guida lo dice esplicitamente solo per `drafts.send`; per `messages.send` è il comportamento documentato della history ma non l'ho trovato scritto nella pagina di invio. [I]
- 35 MB si applicano al messaggio **codificato**: con base64 (+~33 %) restano circa 25 MB di allegati, coerente con il limite della webmail. [I]
- API e SMTP non cambiano gli scope (abbiamo già `https://mail.google.com/`). L'API vince perché ADR 0002 ha già scelto Gmail API, restituisce l'id del messaggio creato (utile per aggiornare subito il DB locale) e supporta `threadId`. [I]

## 2. Microsoft (Graph)

### Fatti

- `POST /me/sendMail` accetta JSON (`application/json`) oppure MIME codificato in base64 (`Content-Type: text/plain`); in MIME allegati e proprietà S/MIME vanno dentro il MIME. Salva in **Posta inviata** di default (`saveToSentItems`, default `true`). Risponde `202 Accepted` senza corpo e senza id. Permesso: `Mail.Send`. [F] — https://learn.microsoft.com/en-us/graph/api/user-sendmail?view=graph-rest-1.0 (aggiornata 2026-06-19)
- Il `202` non garantisce che l'elaborazione sia completata; la consegna è soggetta ai limiti di Exchange Online. [F] — stessa pagina
- MIME è supportato anche per creare bozze (`POST /me/messages`), reply, forward; Graph non permette di modificare singole proprietà MIME. [F] — https://learn.microsoft.com/en-us/graph/outlook-send-mime-message
- Allegati: sotto 3 MB un singolo POST su `attachments`; tra 3 e 150 MB serve un'**upload session** su un messaggio esistente (bozza), PUT a blocchi consigliati sotto 4 MB, poi invio della bozza. Serve `Mail.ReadWrite`. [F] — https://learn.microsoft.com/en-us/graph/outlook-large-attachments
- Alternativa SMTP AUTH con OAuth: scope `https://outlook.office.com/SMTP.Send`, SASL XOAUTH2; vale per Microsoft 365 e Outlook.com. [F] — https://learn.microsoft.com/en-us/exchange/client-developer/legacy-protocols/how-to-authenticate-an-imap-pop-smtp-application-by-using-oauth

### Inferenze

- Graph non restituisce l'id del messaggio inviato: il DB locale lo ritrova con la delta query successiva, abbinandolo per `internetMessageId` (che impostiamo noi nel MIME). [I]
- Il percorso con upload session lavora su un oggetto `message` di Graph, non su MIME grezzo: un messaggio PGP/MIME o S/MIME firmato o cifrato (ADR 0012) di grandi dimensioni non può passarci senza che Exchange ricostruisca il MIME e invalidi la firma. [I, da verificare]
- La documentazione di `sendMail` non indica un limite di dimensione per il corpo MIME; il limite di 4 MB per richiesta Graph è citato solo come consiglio per i blocchi di upload. Il limite reale di `sendMail` MIME va misurato. [I]
- SMTP AUTH per Microsoft richiederebbe uno scope in più (`SMTP.Send`) e un token separato per la risorsa `outlook.office.com` (che però serve già per IDLE, ADR 0008). Il tenant può disabilitare SMTP AUTH e ci sono segnalazioni di errori `535 5.7.3` con account personali. [I; fonti secondarie: https://learn.microsoft.com/en-us/answers/questions/1168242/smtp-send-oauth-permission-not-working-for-consume]
- Sulla copia in Posta inviata quando si invia via SMTP le fonti secondarie sono in conflitto (https://services.dartmouth.edu/TDClient/1806/Portal/KB/ArticleDet?ID=168187 dice di no). Non risolto. [I]

## 3. iCloud e altri Provider IMAP

### Fatti

- iCloud: IMAP `imap.mail.me.com:993` SSL; SMTP `smtp.mail.me.com:587`, SSL/TLS o STARTTLS, autenticazione obbligatoria, utente = indirizzo iCloud completo, password = **password specifica per app** (la stessa di IMAP). [F] — https://support.apple.com/en-us/102525
- `enough_mail` 3.0.0 (pubblicato il 2026-10-26, editore verificato enough.de): `SmtpClient` con `AuthMechanism.plain`, `login`, `xoauth2` (il token come password), invio con `BDAT` se il server annuncia `CHUNKING`. [F] — codice sorgente `lib/src/smtp/smtp_client.dart` del pacchetto, https://pub.dev/packages/enough_mail
- `MailClient.sendMessage(..., appendToSent: true, sentMailbox: …)`: dopo l'invio fa APPEND nella mailbox con flag `\Sent` (flag `\Seen`) se il server supporta l'append; `appendToSent: false` per i Provider che salvano da soli. `saveDraftMessage` fa APPEND nella cartella Bozze. Autodiscovery con `Discover.discover(email)` (RFC 6186). [F] — `lib/src/mail/mail_client.dart` del pacchetto, righe ~909-1046

### Inferenze

- Apple non offre OAuth per la posta iCloud a client terzi: la password per app è l'unica via, e va salvata nel portachiavi come gli altri segreti (ADR 0003). Quando l'utente la revoca l'Account diventa **Da ricollegare** (ADR 0008). [I]
- iCloud non salva da solo una copia degli inviati via SMTP: il client deve fare APPEND in "Sent Messages". Non ho trovato una fonte Apple che lo dica; va verificato. [I]
- Per le Bozze su IMAP non esiste "update": si fa APPEND della nuova versione e si elimina (flag `\Deleted` + `UID EXPUNGE`) quella precedente. L'UID della bozza cambia a ogni salvataggio. [I, segue da RFC 3501/4315]

## 4. Pacchetti Flutter/Dart

| Bisogno | Pacchetto | Stato al 2026-10-28 |
|---|---|---|
| MIME, SMTP, IMAP | `enough_mail` 3.0.0 | attivo (rilascio 2026-10-26) [F] |
| Gmail API | `googleapis` 17.0.0 (`gmail/v1`) | attivo (rilascio 2026-08-24) [F] |
| Microsoft Graph | nessun SDK ufficiale Dart; `microsoft_graph_api` 0.0.14 (2025-09) e `microsoft_graph` 0.0.13 (2019) sono comunitari e immaturi | [F] pub.dev |
| OAuth | `flutter_appauth` 12.1.0 | attivo (rilascio 2026-08-29) [F] |

[R] Per Graph bastano poche chiamate REST (`sendMail`, `messages`, `createUploadSession`, `send`): `package:http` diretto, nessuna dipendenza comunitaria. Il MIME si costruisce sempre con `MessageBuilder` di `enough_mail`, uguale per tutti e tre gli adapter: così PGP/S/MIME (ADR 0012) si fa una volta sola.

## 5. Bozze e Inviati per Provider

| | Invio | Inviati | Bozze |
|---|---|---|---|
| Gmail (API) | `messages.send` `raw`, o `drafts.send` | etichetta `SENT` applicata dal Provider | `drafts.create/update` (id bozza stabile, id messaggio cambia) |
| Microsoft (Graph) | `sendMail` MIME; allegati grandi: bozza + upload session + `POST /messages/{id}/send` | salvato dal Provider (`saveToSentItems`) | `POST /me/messages` (MIME o JSON), `PATCH` per JSON; in MIME non si aggiornano proprietà singole → si ricrea |
| iCloud / IMAP | SMTP | **APPEND del client** in Inviati | APPEND in Bozze con `\Draft`, poi elimina la versione precedente |
| (Gmail via SMTP, non scelto) | SMTP XOAUTH2 | salvato dal Provider; niente APPEND | — |

## 6. Coda offline

[R] L'invio va in coda come intento "assicurati che questo messaggio sia stato inviato", con il MIME già costruito (e già firmato/cifrato) salvato nel DB cifrato e un `Message-ID` generato sul dispositivo. Al replay:

1. Prima di ritentare un invio che potrebbe essere già partito (timeout, risposta persa), cercare il `Message-ID` in Inviati: Gmail con `q=rfc822msgid:<id>`, Graph con `$filter=internetMessageId eq '<id>'` su Posta inviata, IMAP con `UID SEARCH HEADER Message-ID <id>` sulla cartella Inviati. Se c'è, l'intento è compiuto.
2. Se non c'è, inviare. Un errore permanente (destinatario rifiutato, messaggio troppo grande) è l'unico caso mostrato all'utente (ADR 0008).
3. Per IMAP l'APPEND in Inviati è un secondo intento separato, così un APPEND fallito non fa ritentare l'invio SMTP.

[I] Su Graph il controllo del punto 1 può dare falso negativo subito dopo un `202`, perché l'elaborazione è asincrona: serve un'attesa minima prima di decidere di ritentare.

[R] Le bozze si salvano solo nel DB locale mentre si scrive e si sincronizzano sul Provider con un intento "assicurati che la bozza X abbia questo contenuto" a intervalli (debounce), non a ogni battuta.

## Raccomandazione

1. Gmail: Gmail API, MIME grezzo via upload multimediale (supera il limite dei corpi JSON), `threadId` per le risposte. Nessuno scope nuovo.
2. Microsoft: Graph `sendMail` in MIME. Nessuno scope nuovo. Per gli allegati grandi senza firma/cifratura: bozza + upload session + `send`.
3. iCloud e IMAP: SMTP con `enough_mail` (`MailClient.sendMessage`), APPEND in Inviati, password per app per iCloud.
4. Un solo costruttore MIME (`enough_mail`) per tutti gli adapter; `Message-ID` generato sul dispositivo come chiave di idempotenza della coda.

## Punti aperti

- **Messaggi firmati/cifrati grandi su Microsoft**: qual è il limite reale di `sendMail` in MIME? Se è ~4 MB, per i messaggi PGP/S/MIME più grandi servirebbe SMTP XOAUTH2 (`smtp-mail.outlook.com` / `smtp.office365.com`) con lo scope aggiuntivo `SMTP.Send`, o un limite di dimensione esplicito in UI. Da misurare con un account personale e uno Microsoft 365. Potrebbe cambiare la raccomandazione 2.
- **Copia in Posta inviata con SMTP su Microsoft**: fonti in conflitto, rilevante solo se si adotta il fallback SMTP.
- **iCloud salva da solo gli inviati via SMTP?** Da verificare con un invio di prova; se sì, `appendToSent: false` per iCloud.
- **Riconoscimento del Provider per gli "altri IMAP"** che salvano da soli gli inviati (per esempio Gmail via IMAP, Fastmail): serve una lista o una verifica dopo l'invio per evitare duplicati.
- **Limite di 35 MB su Gmail e di 150 MB per allegato su Graph**: decidere se la UI blocca in composizione o propone un link (Drive/OneDrive), fuori da questo ticket.
