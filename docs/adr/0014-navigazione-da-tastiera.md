---
status: Accettato
date: 2026-10-30
---

# Navigazione da tastiera e scorciatoie

Frecce, Invio ed Esc sono sempre attivi; in più ci sono le scorciatoie a lettera singola in stile Gmail: **j**/**k** per la Conversazione successiva/precedente e una lettera per ogni azione (archivia, stella, rispondi…) man mano che le azioni arrivano (a partire da #37), nel registro unico delle scorciatoie introdotto da #54. Per ora non si possono disattivare: il backend è Gmail e chi lo usa conosce già questo schema.

Selezione = apertura. Nel layout a due riquadri (lista e Conversazione affiancate) muoversi nella lista con frecce o j/k apre subito la Conversazione: la riga evidenziata è sempre quella aperta, come in Apple Mail e Outlook. Nel layout a un riquadro (finestra stretta) le frecce spostano il focus nella lista, Invio apre, Esc torna alla lista.

## Alternative considerate

- **Solo frecce e modificatori ⌘/Ctrl** (stile Apple Mail): scartata, chi viene da Gmail si aspetta le lettere.
- **Lettere con un'impostazione per disattivarle**: scartata per ora (un'impostazione in più senza un bisogno reale); si aggiunge se le attivazioni accidentali diventano un problema.
- **Cursore separato dall'apertura, Invio per aprire**: due stati di evidenziazione da distinguere a colpo d'occhio. Scartata.
- **Apertura immediata, segna come letto dopo una permanenza**: un timer e un caso speciale rispetto all'apertura col clic. Scartata.

## Conseguenze

- I tasti a lettera singola vanno ignorati quando il focus è in un campo di testo (composizione, ricerca).
- Scorrere la lista con la tastiera nel layout a due riquadri segna come lette le Conversazioni attraversate, esattamente come aprirle col clic: l'apertura passa da `SyncEngine.openConversation`, che le segna lette subito (anche offline) e accoda la modifica per il Provider.
- Con una selezione di testo attiva nella Conversazione (un solo `SelectionArea`, #69) j/k e Cmd/Ctrl+B funzionano ancora: una selezione non è un campo di testo. Esc annulla prima la selezione, il secondo Esc chiude la Conversazione.
