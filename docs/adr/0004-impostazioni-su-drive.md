---
status: Accettato
date: 2026-10-27
updated: 2026-10-28
---

# Impostazioni di Postino sincronizzate via Google Drive

Le Impostazioni di Postino (Azioni per scorrimento, colori e ordine degli Account, momenti di ritorno di Posticipa, mittenti fidati) si sincronizzano tra dispositivi in un file nascosto nella appDataFolder di Google Drive, con last-write-wins per singola voce. I messaggi posticipati vengono inoltre spostati nell'Etichetta Posticipati sul Provider, così webmail e altri dispositivi concordano. Senza un account Google le impostazioni restano locali e si possono esportare/importare come file, che l'utente conserva o condivide come preferisce.

## Perimetro e milestone

- La sincronizzazione su Drive arriva nella v1.1. Nella v1 le Impostazioni di Postino restano locali, con export/import.
- L'elenco delle voci sincronizzate è chiuso. Ogni altra preferenza è un'Impostazione del dispositivo (Notifiche immediate, avvio al login, tema, Observability, densità), e lo è anche ogni preferenza nuova finché non viene aggiunta a questo elenco.
- Rimuovere un Account su un dispositivo cancella ovunque il suo colore e la sua posizione nell'ordine: il file registra la cancellazione (tombstone), così last-write-wins non la annulla. Sugli altri dispositivi l'Account torna a colore e posizione predefiniti.

## Alternative considerate

- **Tutto locale**: nessuna sincronizzazione, ogni dispositivo da configurare a mano.
- **Data codificata nel nome dell'Etichetta**: fragile e visibile all'utente nella webmail.
- **JSON delle impostazioni in una bozza nascosta**: dipende dal Provider e inquina la casella.

## Conseguenze

- Le impostazioni sincronizzate richiedono uno spazio Google, ma l'export/import le rende utilizzabili anche senza.
- Last-write-wins per voce può perdere una modifica concorrente su dispositivi diversi: accettato per preferenze personali.
