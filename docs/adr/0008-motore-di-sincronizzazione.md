---
status: Accettato
date: 2026-10-27
---

# Motore di sincronizzazione: IDLE come segnale, API per i dati

Finché l'app è aperta (mobile in primo piano, desktop aperto o nella tray) ogni Account tiene una connessione IMAP IDLE sulla posta in arrivo, usata solo come segnale "è cambiato qualcosa". I dati si scaricano poi in modo incrementale: tramite API nativa (Gmail history dall'ultimo historyId, delta query di Microsoft Graph) oppure con IMAP CONDSTORE/QRESYNC per gli Account IMAP. Un polling ogni 60 secondi gira sempre, anche con IDLE sano, perché IDLE vede solo la posta in arrivo e non le Bozze o altre cartelle cambiate da un altro client; la sincronizzazione parte anche alla ripresa dell'app e con il pull-to-refresh. Senza backend (ADR 0001) è l'unico modo di avere posta nuova in tempo quasi reale.

Gli scope OAuth si allargano di conseguenza: per Gmail `https://mail.google.com/` (al posto di `gmail.modify`), per Microsoft `IMAP.AccessAsUser.All` in aggiunta a `Mail.ReadWrite` e `Mail.Send`, perché IDLE passa da IMAP.

Eccezione per la v1 (decisione dell'owner sull'issue [#179](https://github.com/camillobucciarelli/postino/issues/179)): per gli Account Microsoft personali si chiedono solo `openid email offline_access User.Read Mail.ReadWrite Mail.Send`, **senza** `IMAP.AccessAsUser.All`. Microsoft sincronizza con il solo polling ogni 60 secondi, senza segnale IDLE; se servirà, lo scope si aggiunge con un nuovo consenso.

La coda offline conserva intenti idempotenti (per esempio "assicurati che sia archiviato"), non operazioni. Ogni intento in coda salva anche il valore che il messaggio aveva quando è stato accodato; più intenti sullo stesso attributo dello stesso messaggio si fondono, vince l'ultimo. Al replay, se il Provider ha ancora quel valore (o già il valore voluto) l'intento si applica; se ha un valore diverso, cioè è stato modificato altrove, nasce un Conflitto: l'intento resta sospeso finché l'utente sceglie se tenere la propria modifica o quella del Provider. L'intento viene scartato in silenzio solo se il messaggio di destinazione non esiste più (Elimina quindi non genera mai Conflitti); i messaggi in coda si riconoscono dal Message-ID. Oltre ai Conflitti, all'utente si mostrano solo un invio fallito e lo stato della sincronizzazione ([#251](https://github.com/camillobucciarelli/postino/issues/251)): una riga sotto la barra della lista dice se è in corso, quando è riuscita l'ultima volta, se l'ultima non è riuscita (finché una successiva riesce) o se il dispositivo è offline. Lo stato è per Account, tenuto in memoria (non nel database); la Posta unificata lo riassume. Un `OfflineFailure` con il dispositivo online è un intoppo finché non si ripete tre volte di fila: da lì è «Aggiornamento non riuscito», non «Offline». I singoli intenti scartati restano invisibili.

Quando un Provider rifiuta l'accesso a un Account (password cambiata, accesso revocato), l'Account diventa **Da ricollegare**: la sua sincronizzazione si ferma da sola, la posta resta leggibile e la coda attende. Un Banner nella sua posta in arrivo e un punto nell'AccountSwitcher portano ad accedere di nuovo.

## Alternative considerate

- **Gmail push con `users.watch` + Pub/Sub**: serve un server o credenziali del servizio Pub/Sub distribuite dentro l'app. Scartata.
- **Notifiche di modifica di Microsoft Graph**: richiedono un webhook HTTPS pubblico. Scartata (ADR 0001).
- **Solo polling**: scope più stretti, ma fino a 60 secondi di ritardo sulla posta nuova.
- **Notificare ogni azione scartata al replay**: rumore per l'utente, che non può farci nulla.

## Conseguenze

- La schermata di consenso mostra scope più ampi.
- Due connessioni per ogni Account Google (IDLE + API); per Microsoft in v1 solo le chiamate a Graph, senza IDLE.
- Il comportamento in background su mobile non cambia (ADR 0001).
