---
status: Accettato
date: 2026-10-27
---

# Impostazioni di Postino sincronizzate via Google Drive

Le Impostazioni di Postino (Azioni per scorrimento, colori e ordine degli Account, momenti di ritorno di Posticipa) si sincronizzano tra dispositivi in un file nascosto nella appDataFolder di Google Drive, con last-write-wins per singola voce. I messaggi posticipati vengono inoltre spostati nell'Etichetta Posticipati sul Provider, così webmail e altri dispositivi concordano. Senza un account Google le impostazioni restano locali e si possono esportare/importare come file, che l'utente conserva o condivide come preferisce.

## Alternative considerate

- **Tutto locale**: nessuna sincronizzazione, ogni dispositivo da configurare a mano.
- **Data codificata nel nome dell'Etichetta**: fragile e visibile all'utente nella webmail.
- **JSON delle impostazioni in una bozza nascosta**: dipende dal Provider e inquina la casella.

## Conseguenze

- Le impostazioni sincronizzate richiedono uno spazio Google, ma l'export/import le rende utilizzabili anche senza.
- Last-write-wins per voce può perdere una modifica concorrente su dispositivi diversi: accettato per preferenze personali.
