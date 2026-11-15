# Materiale per App Store Connect

Materiale per la scheda di Postino sull'App Store iOS/iPadOS e sul Mac App Store (#326). Un solo bundle ID, quindi un solo record con le due piattaforme.

| File | Contenuto |
|---|---|
| [scheda-it.md](scheda-it.md) | Nome, sottotitolo, testo promozionale, descrizione, parole chiave, categoria, copyright (italiano) |
| [scheda-en.md](scheda-en.md) | Lo stesso in inglese |
| [note-revisione.md](note-revisione.md) | Note per il revisore Apple (inglese): account demo, Gmail non verificato, IA sul dispositivo, Drive, nessun account Postino |
| [app-privacy.md](app-privacy.md) | Risposte per l'etichetta App Privacy e per il questionario sull'età |
| [screenshot.md](screenshot.md) | Elenco delle schermate e risoluzioni; stato: da produrre |
| [checklist-titolare.md](checklist-titolare.md) | Azioni manuali in App Store Connect |

## Limiti di lunghezza (caratteri)

| Campo | Limite | IT | EN |
|---|---|---|---|
| Nome | 30 | 7 | 7 |
| Sottotitolo | 30 | 26 | 27 |
| Testo promozionale | 170 | 170 | 149 |
| Descrizione | 4000 | 3287 | 3142 |
| Parole chiave | 100 | 99 | 98 |

## Affermazioni non verificate

Verificate nel codice: tutte le funzioni nominate nelle schede, tranne quanto segue.

- **iPhone/iPad**: nessuna build iOS è stata avviata in questa sessione (iOS arriva con #323). Layout «affiancato» su iPad, tastiera e notifiche con pulsanti sono letti nel codice (`posta_layout.dart`, `posta_shortcuts.dart`, `notification_buttons.dart` registra le categorie iOS e macOS), non provati su iPad.
- **Icona nella barra dei menu del Mac**: c'è (`tray.open` in `lib/i18n`), ma nella variante sandbox del Mac App Store dipende da #215 e #325.
- **Modello da circa 165 MB**: vale per iOS, iPadOS e Mac Apple Silicon (formato `.litertlm`, ADR 0015); su Mac Intel il file è il GGUF da circa 310 MB. La scheda dice 165 MB.
- **Etichettatura automatica**: il codice la offre solo dove l'Account ha Etichette vere (Gmail), non sulle cartelle IMAP e Microsoft (verifica di Codex su `AutoLabelsView`); le schede la limitano a Gmail.
- **Tema scuro**: non menzionato perché non l'ho trovato nel codice.
- **Impostazioni su Drive**: la scheda e le note dicono che passano solo impostazioni, mai password. L'ADR 0019 (accettato il 15/11/2026) prevede di portare anche le credenziali, cifrate; non è ancora nel codice né nell'informativa. **Se l'ADR 0019 viene implementato prima della pubblicazione, riscrivere** «Mai la posta, mai le password» nelle schede e nelle note, e aggiornare l'informativa.
- **Informativa nelle Impostazioni dell'app**: richiesta da #323, non ancora nel codice; le note di revisione la citano.
- **Fascia d'età**: calcolata da Apple al salvataggio, non prevedibile con certezza.
- **Funzioni che non esistono e quindi non compaiono**: Posticipa, Sessione di smistamento, Regole, PGP/S-MIME, Inviti. Sono nel glossario ma non nel codice.
- **Prezzo**: non indicato nelle schede, è una decisione del titolare.
