# Ricerca sul server per Provider

Ticket: [#6](https://github.com/camillobucciarelli/postino/issues/6) (mappa #1). Contesto: [ADR 0002](../adr/0002-api-native-e-imap.md) (Gmail API, Microsoft Graph, IMAP per gli altri) e [ADR 0003](../adr/0003-offline-first-db-cifrato.md) (ricerca full-text locale, "cerca sul server" come fallback).

**Domanda.** Quali API di ricerca sul server offrono Gmail, Microsoft Graph e IMAP, con quale sintassi e quali limiti (paginazione, corpo, allegati, rate limit)? Come si traduce una sola query utente sui tre canali?

Fonti consultate il 2026-10-28. Legenda: **[F]** fatto osservato in una fonte primaria, **[I]** inferenza, **[R]** raccomandazione.

## Risposta breve

Tutti e tre i canali sanno cercare mittente, destinatari, oggetto, corpo e date sul server. Cambiano tre cose: la sintassi, il modo di paginare e quali filtri si possono combinare.

- **Gmail** accetta la stessa sintassi della casella di ricerca web nel parametro `q`.
- **Graph** usa KQL dentro `$search`, con un tetto di 1.000 risultati e senza `$filter` né `$orderby`.
- **IMAP** ha solo le chiavi di `SEARCH`, con match a sottostringa, una cartella per volta, e restituisce tutti gli UID senza paginazione.

[R] La strada consigliata è un piccolo modello di query interno (`SearchQuery`) che ogni adapter traduce nel proprio dialetto. Quello che un Provider non sa filtrare sul server (per esempio `is:unread` su Graph) si filtra in locale sui risultati. Il modello resta volutamente povero: testo libero, frase esatta, from, to, oggetto, ha allegati, intervallo di date, Etichetta, non letto, Stella.

## 1. Gmail API

- **[F] Endpoint.** `users.messages.list` (anche `users.threads.list`) con il parametro `q`, che usa "la stessa sintassi della casella di ricerca Gmail". Il parametro `q` non è usabile con lo scope `gmail.metadata`. [messages.list](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/list)
- **[F] Paginazione.** `maxResults` vale 100 di default, al massimo 500. Si prosegue con `pageToken`/`nextPageToken`. `resultSizeEstimate` è solo una stima. `includeSpamTrash` vale false di default. La lista restituisce solo id e threadId, quindi servono `messages.get` (o batch) per le intestazioni. [messages.list](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/list)
- **[F] Operatori:** `from:`, `to:`, `cc:`, `bcc:`, `subject:`, `"frase"`, `+parola`, `-esclusione`, `OR`/`{}`, `( )`, `AROUND n`, `has:attachment`, `filename:`, `after:`/`before:`, `older_than:`/`newer_than:`, `larger:`/`smaller:`, `label:`, `in:` (`anywhere`, `archive`, `snoozed`), `is:` (`unread`, `starred`, ...), `category:`, `list:`, `deliveredto:`, `rfc822msgid:`. [Gmail Help 7190](https://support.google.com/mail/answer/7190)
- **[F] Differenze tra API e interfaccia web.** Le date di `after:`/`before:` sono interpretate come mezzanotte PST: per altri fusi bisogna passare epoch in secondi (`after:1388552400`). L'API non espande gli alias in `from:` e non supporta la ricerca estesa a tutto il thread. Copre "la maggior parte" della sintassi della UI, non tutta. [Gmail API, Searching for messages](https://developers.google.com/workspace/gmail/api/guides/filtering)
- **[F] Quote.** 6.000 unità al minuto per utente e 1.200.000 al minuto per progetto. `messages.list` costa 5 unità, `threads.list` 10, `messages.get` 20 (60 con `format=full/raw`). [Quota](https://developers.google.com/workspace/gmail/api/reference/quota)
- **[I] Costo di una ricerca tipica.** Una pagina da 50 risultati con `messages.get format=metadata` costa circa 5 + 50×20 = 1.005 unità, cioè circa 6 ricerche al minuto per utente prima del throttling. Conviene quindi pagine piccole (25–50) e niente prefetch dei corpi.
- **[F] Gmail via IMAP.** Esiste `X-GM-RAW`, che accetta la sintassi web dentro `SEARCH` (`SEARCH X-GM-RAW "has:attachment in:unread"`), annunciato da `X-GM-EXT-1`. [Gmail IMAP extensions](https://developers.google.com/workspace/gmail/imap/imap-extensions) Per l'ADR 0002 Gmail passa dalla API: questo serve solo come riferimento.
- **Allegati.** [F] `filename:` cerca per nome del file. Il contenuto degli allegati non è coperto in modo documentato dalle fonti API consultate.

## 2. Microsoft Graph

### 2a. `$search` su `/me/messages` (o `/me/mailFolders/{id}/messages`)

- **[F] Sintassi KQL.** Senza proprietà, la ricerca copre `from`, `subject` e `body`. Proprietà ricercabili: `attachment` (nomi dei file), `bcc`, `body`, `cc`, `from`, `hasAttachments`, `importance`, `kind`, `participants`, `received`, `recipients`, `sent`, `size`, `subject`, `to`. I risultati sono ordinati per data di invio e una richiesta `$search` "restituisce fino a 1.000 risultati". [Use $search](https://learn.microsoft.com/en-us/graph/search-query-parameter)
- **[F] Paginazione.** La pagina di default è di 10, `$top` va da 1 a 1000. Si prosegue con `@odata.nextLink`, senza manipolare `$skip`. Il corpo arriva in HTML, salvo `Prefer: outlook.body-content-type="text"`. [List messages](https://learn.microsoft.com/en-us/graph/api/user-list-messages?view=graph-rest-1.0)
- **[F, fonte secondaria] Combinazioni.** `$search` non si combina con `$orderby` e, sui messaggi, nemmeno con `$filter`. Anche `$skip` con `$search` è segnalato come non supportato. [Microsoft Q&A 1401458](https://learn.microsoft.com/en-us/answers/questions/1401458/using-search-and-filter-parameters-for-messages-en), [Nylas guide](https://cli.nylas.com/guides/microsoft-graph-mail-query). La pagina ufficiale di `$search` non lo dice in modo esplicito per i messaggi: va verificato (vedi Punti aperti).
- **[F] Throttling (Outlook, per app e per mailbox).** 10.000 richieste ogni 10 minuti e 4 richieste concorrenti. [Throttling limits](https://learn.microsoft.com/en-us/graph/throttling-limits#outlook-service-limits)

### 2b. Microsoft Search API (`POST /search/query`, `entityTypes: ["message"]`)

- **[F] Cosa offre.** Cerca anche nel **contenuto degli allegati** e ordina per `receivedDateTime` decrescente (o per rilevanza con `enableTopResults`). Pagina con `from`/`size`. **Solo account di lavoro o scuola** e solo la mailbox dell'utente. `total` riporta il numero di risultati della pagina, non il totale. [Search Outlook messages](https://learn.microsoft.com/en-us/graph/search-concept-messages)
- **[I] Conseguenza.** Non copre gli account Outlook.com personali, quindi non può essere il canale unico. Al massimo è un miglioramento per gli account Microsoft 365.

## 3. IMAP (tutti gli altri Provider)

- **[F] `SEARCH` base.** Per IMAP4rev1 il match sulle stringhe è una sottostringa, case-insensitive. [RFC 3501 §6.4.4](https://www.rfc-editor.org/rfc/rfc3501#section-6.4.4) IMAP4rev2 lo rende "SHOULD" per ASCII. Su `BODY` il server può fare match flessibile: forme flesse, oppure solo parole intere, per cui "swim" può non trovare "swimming". Può anche escludere dalla ricerca le parti MIME che non sono testo, cioè gli allegati. [RFC 9051 §6.4.4](https://www.rfc-editor.org/rfc/rfc9051#section-6.4.4)
- **[F] Chiavi utili:** `FROM`, `TO`, `CC`, `BCC`, `SUBJECT`, `BODY`, `TEXT` (intestazioni + corpo), `HEADER <campo> <stringa>`, `SINCE`/`BEFORE`/`ON` (data interna, al giorno), `SENTSINCE`/`SENTBEFORE`, `LARGER`/`SMALLER`, `SEEN`/`UNSEEN`, `FLAGGED`, `KEYWORD`, `OR`, `NOT`. Charset: IMAP4rev2 assume UTF-8, mentre i server rev1 devono supportare `CHARSET UTF-8`. [RFC 9051 §6.4.4](https://www.rfc-editor.org/rfc/rfc9051#section-6.4.4)
- **[F] Ambito e paginazione.** `SEARCH` lavora sulla cartella selezionata e restituisce *tutti* gli UID che corrispondono, senza ordinamento né paginazione. Le estensioni:
  - `ESEARCH` ([RFC 4731](https://www.rfc-editor.org/rfc/rfc4731), incluso in IMAP4rev2) aggiunge `RETURN (MIN MAX COUNT ALL)`.
  - `PARTIAL` ([RFC 9394](https://www.rfc-editor.org/rfc/rfc9394)) pagina: `UID SEARCH RETURN (PARTIAL -1:-50) ...` restituisce le 50 più recenti.
  - `MULTISEARCH` ([RFC 7377](https://www.rfc-editor.org/rfc/rfc7377)) cerca su più cartelle.
  - `SORT` ([RFC 5256](https://www.rfc-editor.org/rfc/rfc5256)) ordina lato server.
  - `FUZZY` ([RFC 6203](https://www.rfc-editor.org/rfc/rfc6203)) aggiunge il match approssimato.
- **[F] Capability pre-login osservate il 2026-10-28** (probe `CAPABILITY` senza autenticazione; dopo il login la lista può cambiare):
  - `imap.gmail.com`: `IMAP4REV1 … X-GM-EXT-1`
  - `imap.mail.me.com` (iCloud): solo `IMAP4REV1 SASL-IR XAPPLEPUSHSERVICE` + auth
  - `imap.fastmail.com`: `IMAP4REV2 … SORT CONDSTORE QRESYNC`; `ESEARCH` è implicito in rev2
  - `outlook.office365.com`: `IMAP4REV1 … LOGINDISABLED`
- **[F] Dovecot.** `SEARCH BODY`/`TEXT` usa l'indice FTS solo se è configurato un driver (`fts_driver`: `flatcurve`/Xapian, `solr`, o `dovecot` nella versione Pro). Gli allegati sono indicizzati solo con `fts_decoder_driver` (`tika` o `script`). Con `fts_search_read_fallback=yes` (il default), se l'FTS fallisce Dovecot ripiega su una scansione che "può aprire ogni messaggio". [Dovecot 2.4 FTS](https://doc.dovecot.org/2.4.1/core/plugins/fts.html)
- **[I] Prestazioni.** Su server senza FTS (Dovecot non configurato, molti hosting condivisi) una ricerca `BODY` scansiona la cartella e può richiedere decine di secondi su caselle grandi. Serve un timeout e un'interfaccia che mostri i risultati progressivi cartella per cartella.
- **[F] Libreria.** `enough_mail` espone `uidSearchMessages(searchCriteria: String, returnOptions: List<ReturnOption>?)`. `ReturnOption` ha `min`, `max`, `all`, `count`, `partial(rangeSet)`, quindi ESEARCH e PARTIAL sono già raggiungibili. La stringa di criteri è libera: l'escaping e il quoting li fa l'adapter. [uidSearchMessages](https://pub.dev/documentation/enough_mail/latest/enough_mail/ImapClient/uidSearchMessages.html), [ReturnOption](https://pub.dev/documentation/enough_mail/latest/enough_mail/ReturnOption-class.html)

## Tabella comparativa

| | Gmail API | Graph `$search` | Graph Search API | IMAP `SEARCH` |
|---|---|---|---|---|
| Sintassi | operatori Gmail in `q` | KQL in `$search="…"` | KQL in `queryString` | chiavi RFC (`FROM`, `TEXT`, …) |
| Ambito | tutta la casella (`label:`/`in:` per restringere) | casella o singola cartella | casella | una cartella (salvo `MULTISEARCH`) |
| Corpo full-text | sì | sì (`body:`) | sì | sì (`BODY`/`TEXT`, qualità variabile) |
| Contenuto allegati | non documentato (nome file: `filename:`) | solo nome (`attachment:`) | **sì** | dipende dal server (Dovecot + Tika) |
| Match | parole/frasi | token KQL | token KQL | sottostringa (rev1), flessibile su BODY (rev2) |
| Paginazione | `pageToken`, max 500/pagina | `nextLink`, `$top` ≤ 1000, **tetto 1000 risultati** | `from`/`size` | nessuna (tutti gli UID), `PARTIAL` se c'è |
| Ordinamento | per data, desc | per data di invio | data desc o rilevanza | nessuno (`SORT` se c'è) |
| Filtri stato (non letto, Stella) | `is:unread`, `is:starred` | **no** in `$search`, niente `$filter` | no | `UNSEEN`, `FLAGGED` |
| Account supportati | tutti Gmail | lavoro + personali | **solo lavoro/scuola** | tutti |
| Limiti | 6.000 unità/min/utente | 10.000 req/10 min, 4 concorrenti per mailbox | come Outlook | dipende dal server |

## Mappatura di una query utente

[R] `SearchQuery` interno (proposta minima):

```
SearchQuery {
  terms: List<String>      // testo libero, in AND
  phrase: String?          // "frase esatta"
  from, to, subject: String?
  hasAttachment: bool?
  after, before: DateTime? // giorno locale dell'utente
  label: Etichetta?        // opzionale, restringe l'ambito
  unread, starred: bool?
}
```

| Campo | Gmail `q` | Graph `$search` (KQL) | IMAP `UID SEARCH` |
|---|---|---|---|
| terms | `foo bar` | `foo bar` (from+subject+body) | `TEXT "foo" TEXT "bar"` |
| phrase | `"a b"` | `"\"a b\""` (escape) | `TEXT "a b"` |
| from | `from:x` | `from:x` | `FROM "x"` |
| to | `to:x` | `to:x` (o `recipients:`) | `TO "x"` |
| subject | `subject:(x)` | `subject:x` | `SUBJECT "x"` |
| hasAttachment | `has:attachment` | `hasAttachments:true` | approssimato: `HEADER Content-Type "multipart/mixed"`, poi verifica in locale su BODYSTRUCTURE |
| after/before | `after:<epoch> before:<epoch>` (evita il PST) | `received>=YYYY-MM-DD` / `received<=…` ([KQL](https://learn.microsoft.com/en-us/sharepoint/dev/general-development/keyword-query-language-kql-syntax-reference)) | `SINCE d BEFORE d` (al giorno, data interna) |
| label | `label:x` / `in:x` | endpoint `/mailFolders/{id}/messages` | `SELECT` della cartella |
| unread | `is:unread` | **filtro locale** sui risultati (`isRead`) | `UNSEEN` |
| starred | `is:starred` | **filtro locale** (`flag/flagStatus`) | `FLAGGED` |

[R] Regole per ogni adapter:

1. **Gmail.** Tradurre in `q` e usare `messages.list` con `maxResults` tra 25 e 50, recuperando solo i metadati. Le date vanno sempre in epoch.
2. **Graph.** Usare solo `$search`. I filtri di stato si applicano in locale e il tetto di 1.000 si dichiara nell'interfaccia ("mostrati i primi 1.000"). Se l'account è di lavoro o scuola si potrà passare in seguito alla Search API per avere gli allegati.
3. **IMAP.**
   - `UID SEARCH CHARSET UTF-8 …` sulle cartelle rilevanti: Posta in arrivo, Archivio/Tutti, Inviati. Se c'è un'Etichetta si cerca solo nella sua cartella.
   - Se c'è `PARTIAL` si chiede `RETURN (PARTIAL -1:-50)`. Altrimenti si prendono tutti gli UID, si ordinano in modo decrescente (approssima la data) e si fa `FETCH ENVELOPE` a blocchi di 50.
   - Con `ESEARCH` si usa `RETURN (COUNT …)` per il conteggio.
4. **Comune.**
   - I risultati del server vengono inseriti nel database locale (ADR 0003) come intestazioni "fuori finestra", così la UI continua a leggere solo dal DB.
   - Si fa deduplica per `Message-ID` (Gmail id, Graph id, UID+UIDVALIDITY).
   - Ogni Account è cercato in parallelo, con un timeout per Account.

## Punti aperti

1. **Graph `$search` + `$filter`/`$orderby`/`$skip` sui messaggi.** L'incompatibilità viene da fonti secondarie. Va verificata con una chiamata reale; se `$filter=isRead eq false` fosse accettato, il filtro locale non servirebbe.
2. **Capability post-login di iCloud e Fastmail** (ESEARCH, PARTIAL, MULTISEARCH, FUZZY). Il probe era pre-login: iCloud non annuncia nulla prima dell'autenticazione. Serve un `CAPABILITY` dopo il login con un account di prova.
3. **Qualità di `BODY` su iCloud.** Non è documentato se il server indicizza il full-text o se fa match a parola intera; va misurato su una casella reale.
4. **Contenuto degli allegati in Gmail API.** La UI web sembra cercarci, ma la documentazione API non lo garantisce: va verificato prima di prometterlo nell'interfaccia.
5. **Search API per account Microsoft 365.** Va deciso se aggiungerla subito, in cambio di un secondo percorso di codice e di un permesso in più, o rimandarla.
6. **Graph per account personali.** Va verificato che `$search` su `/me/messages` dia gli stessi risultati per Outlook.com e per Microsoft 365.

## Fonti

- Gmail API `users.messages.list`: https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/list
- Gmail API, ricerca e filtri: https://developers.google.com/workspace/gmail/api/guides/filtering
- Gmail API, quote: https://developers.google.com/workspace/gmail/api/reference/quota
- Operatori di ricerca Gmail: https://support.google.com/mail/answer/7190
- Estensioni IMAP di Gmail: https://developers.google.com/workspace/gmail/imap/imap-extensions
- Graph `$search`: https://learn.microsoft.com/en-us/graph/search-query-parameter
- Graph List messages: https://learn.microsoft.com/en-us/graph/api/user-list-messages?view=graph-rest-1.0
- Graph throttling: https://learn.microsoft.com/en-us/graph/throttling-limits
- Microsoft Search API per i messaggi: https://learn.microsoft.com/en-us/graph/search-concept-messages
- Sintassi KQL: https://learn.microsoft.com/en-us/sharepoint/dev/general-development/keyword-query-language-kql-syntax-reference
- Microsoft Q&A su `$search` + `$filter`: https://learn.microsoft.com/en-us/answers/questions/1401458/using-search-and-filter-parameters-for-messages-en
- RFC 3501, RFC 9051, RFC 4731, RFC 9394, RFC 7377, RFC 5256, RFC 6203 (rfc-editor.org)
- Dovecot 2.4 FTS: https://doc.dovecot.org/2.4.1/core/plugins/fts.html
- enough_mail: https://pub.dev/documentation/enough_mail/latest/enough_mail/ImapClient/uidSearchMessages.html
