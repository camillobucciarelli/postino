# Materiale per gli store

Materiale per le schede di Postino (sugli store «Postino Mail»; Francia esclusa dalla distribuzione, ADR 0020) sull'App Store e sul Mac App Store (#326) e su Google Play (#345).

## Google Play (#345)

Variante Android «store» (fetta 1 di #345), pacchetto `com.cbucciarelli.postino`, una sola app nella Play Console.

| File | Contenuto |
|---|---|
| [play-scheda-it.md](play-scheda-it.md) | Nome, descrizione breve e completa, categoria, contatti, informativa, grafica (italiano, lingua predefinita) |
| [play-scheda-en.md](play-scheda-en.md) | Nome e descrizioni in inglese |
| [play-dichiarazioni.md](play-dichiarazioni.md) | Sicurezza dei dati, permessi, servizio in primo piano `specialUse` (testo e scaletta del video), classificazione, pubblico, altre dichiarazioni, regole Play, Paesi |
| [play-note-revisione.md](play-note-revisione.md) | Accesso all'app per i revisori (inglese), con i segnaposto della casella demo |
| [play-checklist-titolare.md](play-checklist-titolare.md) | Azioni manuali: creare l'app, Play App Signing, primo AAB, service account, test chiuso, casella demo |
| [grafica/](grafica/) | `icona-512.png` e `grafica-in-evidenza.png` (1024 × 500), da `tool/brand_icons.sh play` |
| [screenshot.md](screenshot.md) | Screenshot del telefono Android (it, en) in `screenshot/android/` |

### Limiti di lunghezza (caratteri)

Fonte: [Google, testi della scheda](https://support.google.com/googleplay/android-developer/answer/9859152), verificata il 16/11/2026.

| Campo | Limite | IT | EN |
|---|---|---|---|
| Nome dell'app | 30 | 12 | 12 |
| Descrizione breve | 80 | 77 | 77 |
| Descrizione completa | 4000 | 3443 | 3258 |

### Requisiti verificati sulle fonti Google (16/11/2026)

| Requisito | Valore | Fonte |
|---|---|---|
| Screenshot del telefono | da 2 a 8; JPEG o PNG a 24 bit senza alfa; lati da 320 a 3840 px, il lungo al massimo il doppio del corto; per le promozioni almeno 4 a 1080 × 1920 o più | [asset grafici](https://support.google.com/googleplay/android-developer/answer/9866151) |
| Screenshot del tablet | lati da 1080 a 7680 px, 16:9 o 9:16; facoltativi per un'app che non dichiara il supporto tablet (**non verificato**: la pagina non lo dice) | idem |
| Grafica in evidenza | 1024 × 500, JPEG o PNG a 24 bit, senza alfa | idem |
| Icona | 512 × 512, PNG a 32 bit, sRGB, massimo 1024 KB, quadrata (maschera e ombra le mette Play) | [specifiche icona](https://developer.android.com/distribute/google-play/resources/icon-design-specifications) |
| Livello API target | 36 per app nuove e aggiornamenti dal 31/08/2026 (Postino: 36) | [target API](https://developer.android.com/google/play/requirements/target-sdk) |
| Account personale | test chiuso con almeno 12 tester iscritti per 14 giorni consecutivi prima della produzione | [test](https://support.google.com/googleplay/android-developer/answer/14151465) |
| Servizi in primo piano | descrizione, impatto, video e use case per ogni tipo | [dichiarazione](https://support.google.com/googleplay/android-developer/answer/13392821) |

Le altre fonti sono citate dove servono, in [play-dichiarazioni.md](play-dichiarazioni.md) e [play-checklist-titolare.md](play-checklist-titolare.md).

### Affermazioni da ricontrollare per Play

- **Dipendono dalla fetta 1 di #345** (non ancora unita quando è stato scritto questo materiale): niente avviso di aggiornamento, niente `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, schermata di sistema dell'ottimizzazione batteria. Lo dicono le note per i revisori e la Sicurezza dei dati; vanno verificate sulla build `store`.
- **Modello da circa 165 MB**: vale per Android arm64 (`.litertlm`, ADR 0015); su Android x86_64 (emulatori, alcuni Chromebook) è il GGUF da circa 310 MB.
- **Impostazioni sincronizzate**: la scheda Play dice che portano anche gli Account collegati, in un file cifrato con la chiave sui dispositivi (ADR 0019, #321 fette 1–4 unite). Il testo dell'app `impostazioni.syncBody` dice ancora «senza credenziali», e l'informativa del sito «mai password o token»: da allineare (fuori da #345).
- **Sicurezza dei dati diversa dall'App Privacy di Apple**: su Play si dichiarano posta, indirizzo, allegati, Segnalazione e i dati di ML Kit (lo scanner del QR), perché Google conta come raccolta ogni trasmissione fuori dal dispositivo; motivi in [play-dichiarazioni.md](play-dichiarazioni.md). Le schede dicono «niente analytics nostri», non «niente analytics».
- **Layout su tablet Android**: non provato; la scheda non lo nomina e non ci sono screenshot tablet.

## App Store (#326)

Un solo bundle ID, quindi un solo record con le due piattaforme.

| File | Contenuto |
|---|---|
| [scheda-it.md](scheda-it.md) | Nome, sottotitolo, testo promozionale, descrizione, parole chiave, categoria, copyright (italiano) |
| [scheda-en.md](scheda-en.md) | Lo stesso in inglese |
| [note-revisione.md](note-revisione.md) | Note per il revisore Apple (inglese): account demo, Gmail non verificato, IA sul dispositivo, Drive, nessun account Postino |
| [app-privacy.md](app-privacy.md) | Risposte per l'etichetta App Privacy e per il questionario sull'età |
| [screenshot.md](screenshot.md) | Elenco delle schermate e risoluzioni; stato: iPhone e iPad pronti (it, en), Mac da produrre |
| [checklist-titolare.md](checklist-titolare.md) | Azioni manuali in App Store Connect |

### Limiti di lunghezza (caratteri)

| Campo | Limite | IT | EN |
|---|---|---|---|
| Nome | 30 | 7 | 7 (sullo Store: «Postino Mail») |
| Sottotitolo | 30 | 26 | 27 |
| Testo promozionale | 170 | 170 | 149 |
| Descrizione | 4000 | 3356 | 3197 |
| Parole chiave | 100 | 99 | 98 |

### Affermazioni non verificate

Verificate nel codice: tutte le funzioni nominate nelle schede, tranne quanto segue.

- **iPhone/iPad**: nessuna build iOS è stata avviata in questa sessione (iOS arriva con #323). Layout «affiancato» su iPad, tastiera e notifiche con pulsanti sono letti nel codice (`posta_layout.dart`, `posta_shortcuts.dart`, `notification_buttons.dart` registra le categorie iOS e macOS), non provati su iPad.
- **Icona nella barra dei menu del Mac**: c'è (`tray.open` in `lib/i18n`), ma nella variante sandbox del Mac App Store dipende da #215 e #325.
- **Modello da circa 165 MB**: vale per iOS, iPadOS e Mac Apple Silicon (formato `.litertlm`, ADR 0015); su Mac Intel il file è il GGUF da circa 310 MB. La scheda dice 165 MB.
- **Etichettatura automatica**: il codice la offre solo dove l'Account ha Etichette vere (Gmail), non sulle cartelle IMAP e Microsoft (verifica di Codex su `AutoLabelsView`); le schede la limitano a Gmail.
- **Tema scuro**: non menzionato perché non l'ho trovato nel codice.
- **Impostazioni su Drive**: con #321 (ADR 0019) il file su Drive porta anche le credenziali degli Account, tutto cifrato con una chiave che resta sui dispositivi. Schede, note e informativa lo dicono dal 16/11/2026 (#348); su App Store Connect descrizione e note di revisione si aggiornano con la prossima versione inviata.
- **Fascia d'età**: calcolata da Apple al salvataggio, non prevedibile con certezza.
- **Funzioni che non esistono e quindi non compaiono**: Posticipa, Sessione di smistamento, Regole, PGP/S-MIME, Inviti. Sono nel glossario ma non nel codice.
- **Prezzo**: non indicato nelle schede; il titolare ha scelto gratis (16/11/2026).
