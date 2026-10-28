---
status: Accettato
date: 2026-10-27
---

# Motore di sincronizzazione: IDLE come segnale, API per i dati

Finché l'app è aperta (mobile in primo piano, desktop aperto o nella tray) ogni Account tiene una connessione IMAP IDLE sulla posta in arrivo, usata solo come segnale "è cambiato qualcosa". I dati si scaricano poi in modo incrementale: tramite API nativa (Gmail history dall'ultimo historyId, delta query di Microsoft Graph) oppure con IMAP CONDSTORE/QRESYNC per gli Account IMAP. Se IDLE cade, si ricade su un polling ogni 60 secondi finché non si riconnette; la sincronizzazione parte anche alla ripresa dell'app e con il pull-to-refresh. Senza backend (ADR 0001) è l'unico modo di avere posta nuova in tempo quasi reale.

Gli scope OAuth si allargano di conseguenza: per Gmail `https://mail.google.com/` (al posto di `gmail.modify`), per Microsoft `IMAP.AccessAsUser.All` in aggiunta a `Mail.ReadWrite` e `Mail.Send`, perché IDLE passa da IMAP.

La coda offline conserva intenti idempotenti (per esempio "assicurati che sia archiviato"), non operazioni. Al replay l'intento viene riapplicato sopra lo stato del Provider, anche se nel frattempo il messaggio è stato modificato altrove (letto, Stella, Etichetta, Posticipa): la modifica concorrente viene sovrascritta. L'intento viene scartato in silenzio solo se il messaggio di destinazione non esiste più; i messaggi in coda si riconoscono dal Message-ID. Solo un invio fallito viene mostrato all'utente.

Quando un Provider rifiuta l'accesso a un Account (password cambiata, accesso revocato), l'Account diventa **Da ricollegare**: la sua sincronizzazione si ferma da sola, la posta resta leggibile e la coda attende. Un Banner nella sua posta in arrivo e un punto nell'AccountSwitcher portano ad accedere di nuovo.

## Alternative considerate

- **Gmail push con `users.watch` + Pub/Sub**: serve un server o credenziali del servizio Pub/Sub distribuite dentro l'app. Scartata.
- **Notifiche di modifica di Microsoft Graph**: richiedono un webhook HTTPS pubblico. Scartata (ADR 0001).
- **Solo polling**: scope più stretti, ma fino a 60 secondi di ritardo sulla posta nuova.
- **Notificare ogni azione scartata al replay**: rumore per l'utente, che non può farci nulla.

## Conseguenze

- La schermata di consenso mostra scope più ampi.
- Due connessioni per ogni Account Google o Microsoft (IDLE + API).
- Il comportamento in background su mobile non cambia (ADR 0001).
