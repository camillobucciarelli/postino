---
status: Accettato
date: 2026-10-27
---

# API native per Gmail e Microsoft, IMAP/SMTP per gli altri

Gmail usa la Gmail API, Microsoft usa Microsoft Graph, tutti gli altri Provider usano IMAP/SMTP (enough_mail, con XOAUTH2 dove serve). I tre canali stanno dietro un'unica interfaccia adapter, con un'istanza per ogni Account. Le API native offrono sincronizzazione differenziale efficiente (historyId, delta query), Etichette native e migliore throughput.

## Alternative considerate

- **IMAP per tutti** (un solo motore): meno codice, ma sync più lenta e senza delta nativi né Etichette native.

## Conseguenze

- Vanno scritti e mantenuti tre adapter.
- L'Etichetta è il concetto unificato: sui Provider basati su cartelle un messaggio ha al massimo un'Etichetta e assegnarla equivale a spostarlo.
