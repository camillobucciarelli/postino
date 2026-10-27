---
status: Accettato
date: 2026-10-27
---

# Offline-first con database locale cifrato

La UI legge solo dal database locale (SQLite + SQLCipher, chiave nel keychain del sistema: Keychain, Credential Manager o libsecret); il motore di sincronizzazione scrive nel database. Le azioni fatte offline vanno in coda e vengono riprodotte alla riconnessione. La finestra di sync è di 90 giorni per le intestazioni, più i corpi della posta in arrivo; il resto si scarica su richiesta. La ricerca è full-text locale, con "cerca sul server" come fallback. Posta unificata su N Account e Sessione di smistamento devono essere istantanee e funzionare offline; la cifratura serve perché i dischi Windows/Linux possono non essere cifrati.

## Alternative considerate

- **Cache leggera**: più semplice, ma Posta unificata e Sessione di smistamento dipenderebbero dalla rete e dalla latenza di ogni Provider.

## Conseguenze

- Serve un motore di sync con coda di azioni offline e gestione dei conflitti.
- I messaggi più vecchi di 90 giorni richiedono rete; la ricerca locale non li copre finché non sono scaricati.
