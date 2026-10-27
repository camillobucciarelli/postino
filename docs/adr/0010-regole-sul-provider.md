---
status: Accettato
date: 2026-10-27
---

# Regole sul Provider, non sul dispositivo

Le Regole si creano e si eseguono sul Provider, mai sul dispositivo: filtri Gmail tramite API, regole della posta in arrivo di Outlook tramite Microsoft Graph, Sieve tramite ManageSieve per gli Account IMAP il cui server lo supporta. Gli Account IMAP senza Sieve non hanno Regole. Così le Regole funzionano anche a tutti i dispositivi spenti (senza backend, ADR 0001, nessun altro posto potrebbe eseguirle), e webmail e notifiche concordano con ciò che l'app mostra.

Il sottoinsieme comune a tutti i Provider, e quindi l'unico offerto, è: condizioni **da**, **a**, **oggetto contiene**, **ha allegato**; azioni **applica Etichetta**, **archivia**, **stella**, **segna come letto**, **elimina**.

Gli scope OAuth si allargano: `gmail.settings.basic` per Gmail, `MailboxSettings.ReadWrite` per Microsoft.

## Alternative considerate

- **Regole locali sul dispositivo**: si applicano solo quando un dispositivo sincronizza, la notifica può partire prima dello spostamento, la webmail diverge. Scartata.
- **Provider, con ripiego locale per IMAP senza Sieve**: due motori con comportamenti diversi sotto la stessa interfaccia. Scartata: meglio nessuna Regola che Regole inaffidabili.

## Conseguenze

- La schermata di consenso mostra altri scope.
- Le Regole offerte sono solo quelle che tutti i Provider sanno esprimere.
- Alcuni Account IMAP non hanno la funzione.
