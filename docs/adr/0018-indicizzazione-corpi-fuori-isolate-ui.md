---
status: Accettato
date: 2026-11-15
---

# Testo dei corpi per la ricerca fuori dall'isolate UI

Il database (`NativeDatabase`, ADR 0003) gira sull'isolate UI. Fino a #221 anche il testo dei corpi HTML per l'indice di ricerca (#205) si faceva lì: nella sync, dentro la sua transazione, e nella migrazione v22 per tutti i corpi già salvati, dentro `onUpgrade`. Su caselle grandi voleva dire frame persi durante la sync e un primo avvio bloccato.

**Decisione (#221).**

- **Sync e corpi aperti.** `MailStore` fa il testo dei corpi (`searchableTexts`, `lib/core/data/search_index.dart`) prima di aprire la transazione e lo passa ai DAO. Oltre 16 KB di HTML nel lotto il parsing gira in un altro isolate (`Isolate.run`), come la cifratura degli allegati grandi; sotto resta sull'isolate UI, dove costa pochi millisecondi e un isolate costerebbe di più.
- **Corpi già salvati.** La migrazione indicizza solo le colonne dei messaggi (SQL puro) e, se ci sono corpi, crea la tabella `search_index_backlog` con il rowid dell'ultimo corpo fatto. All'avvio l'isolate dell'app (`main`) chiama `indexSearchBacklog`: lotti di 50 corpi, testo fatto come sopra, scritto in una transazione insieme al progresso, un giro del ciclo degli eventi tra un lotto e l'altro; finiti i corpi, la tabella si cancella. Un avvio interrotto riprende dall'ultimo lotto scritto.
- **Correttezza.** Il backlog scrive il testo di un corpo solo dove nell'indice è ancora vuoto: un testo scritto nel frattempo dalla sync è più nuovo e resta. Un messaggio rimosso nel frattempo (anche con la Rimozione di un Account) non ha più la sua riga nell'indice, e la scrittura non cambia nulla. Gli isolate in background (WorkManager, notifiche) non lo avviano.

**Scartato.** `NativeDatabase.createInBackground` (tutto SQLite in un isolate dedicato) toglierebbe dall'isolate UI anche le scritture, ma cambia l'apertura cifrata (SQLCipher, chiave, `busy_timeout`) e la concorrenza con gli isolate in background: non serve per il problema di #221.

## Conseguenze

- Dopo l'aggiornamento da una versione senza indice, i corpi già salvati si trovano con la ricerca qualche istante dopo l'avvio, non subito; oggetto, mittente, destinatari e anteprima subito.
- Le scritture SQL (FTS5 compreso) restano sull'isolate UI, a lotti piccoli.
- Il test di prestazioni della ricerca controlla il piano della query (nessuna scansione di tabella oltre l'indice), non il tempo.
