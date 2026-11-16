# Screenshot

**Stato: iPhone e iPad prodotti in italiano e in inglese; Mac mancante** (motivo sotto). Tutte le immagini mostrano solo posta finta: due caselle `demo@example.com` e `demo@example.org` su un server locale, mittenti e domini inventati (`example.com`, `example.org`). Nessun Account, posta o dato del titolare; l'app già installata non è stata aperta.

Le immagini sono in `docs/store/screenshot/<piattaforma>/<lingua>/NN-nome.png`: PNG sRGB senza trasparenza, senza cornici di dispositivo (Apple le rifiuta se non sono lo schermo reale), barra di stato alle 9:41 con batteria piena.

| Piattaforma | Lingue | Dimensione (px) | Dispositivo |
|---|---|---|---|
| `iphone` | `it`, `en` | 1320 × 2868 (verticale) | simulatore iPhone 17 Pro Max, iOS 27.0 |
| `ipad` | `it`, `en` | 2064 × 2752 (verticale) | simulatore iPad Pro 13-inch (M5), iOS 27.0 |
| `mac` | — | — | **mancante** |

## Risoluzioni accettate da App Store Connect

Basta **una** dimensione per famiglia: Apple ridimensiona le altre. Da 1 a 10 screenshot per localizzazione; se ne propongono 5.

| Famiglia | Dimensione (px, verticale × orizzontale) | Simulatore o dispositivo |
|---|---|---|
| iPhone 6.9" (obbligatoria) | 1320 × 2868 (anche 1290 × 2796, 1260 × 2736) | iPhone 17 Pro Max |
| iPad 13" (obbligatoria per iPad) | 2064 × 2752 (anche 2048 × 2732) | iPad Pro 13-inch (M5) |
| Mac | 1280 × 800, 1440 × 900, 2560 × 1600 o 2880 × 1800 | finestra di Postino della build macOS, 1440 × 900 punti (@2x = 2880 × 1800) |

Le dimensioni vanno riverificate su App Store Connect al momento del caricamento: Apple le aggiorna con i nuovi dispositivi.

## Le schermate

1. `01-posta-unificata.png`: **Posta unificata** con i due Account (colori diversi), non letti, Stella e una conversazione da 4 messaggi. Su iPad tre colonne: barra laterale (compatta), lista, una Conversazione con allegato.
2. `02-conversazione.png`: **Conversazione** aperta con corpo HTML, il banner «Immagini remote bloccate», un PDF allegato e le risposte precedenti.
3. `03-ricerca.png`: **Ricerca** con l'operatore `da:marta` (`from:martha` in inglese) e i risultati; su iPad con il risultato aperto accanto.
4. `04-scorrimento.png`: **Azioni per scorrimento** (Impostazioni).
5. `05-nuovo-messaggio.png`: **Nuovo messaggio** nell'editor, con destinatario, oggetto e testo.

Le **Etichette automatiche** previste prima come schermata 4 non ci sono: valgono solo per le Etichette di un Account Gmail (`auto_labels_view.dart` mostra solo `LabelKind.etichetta`), e un Account Gmail finto non si può collegare senza un account Google vero. La 4 è diventata «Azioni per scorrimento», la 5 «Nuovo messaggio».

## Mancanti

- **Mac**: l'app esige TLS (SSL o STARTTLS, `imap_session.dart`) e non accetta certificati non fidati, nemmeno in debug. Il server finto usa una CA usa-e-getta: sul simulatore iOS è fidata con `xcrun simctl keychain <udid> add-root-cert`, che tocca solo il simulatore; su macOS andrebbe resa fidata nel portachiavi dell'utente o di sistema, cioè cambiando le impostazioni di sicurezza del Mac. Non l'ho fatto. Per produrli: renderla fidata a mano (Accesso Portachiavi, poi toglierla), oppure usare una casella demo vera su un server con un certificato pubblico; poi build macOS con bundle id diverso (per esempio `com.cbucciarelli.postino.storeqa`, mai committato) e `screencapture -o -l <id finestra>` a 1440 × 900 punti. Il driver qui sotto non serve sul Mac (la cattura è con `screencapture`, non `simctl`).

## Come rifarli (iPhone e iPad)

Servono Java (17+), `python3`, `openssl@3` di Homebrew e `fvm`. Il server finto è [GreenMail](https://greenmail-mail-test.github.io/greenmail/) 2.1.15, lo stesso jar (da Maven Central, SHA-256 verificato) dei test `imap` (`test/support/greenmail_server.dart`).

1. `tool/store_screenshots/server.sh <it|en> <cartella temporanea>`: crea nella cartella una CA e un certificato per `localhost` validi 30 giorni (rifatti quando scadono: la nuova CA va rifidata nel simulatore), avvia GreenMail su `127.0.0.1` (IMAPS 3993, SMTPS 3465) con le caselle `demo@example.com` e `demo@example.org` (password `demo-pass`) e le riempie con `seed.py` (22 messaggi in arrivo, tra cui una conversazione da 4 con la risposta in Inviati, Bozze, Cestino, due cartelle, HTML con immagine remota, PDF allegati). La posta è in memoria: Ctrl-C la cancella.
2. Un simulatore dedicato (`xcrun simctl create`), avviato, con la lingua scelta (`xcrun simctl spawn <udid> defaults write -g AppleLanguages -array it` e `AppleLocale it_IT`, poi riavvio) e la CA fidata: `xcrun simctl keychain <udid> add-root-cert <cartella>/ca.pem`.
3. `tool/store_screenshots/shots.sh <udid> <iphone|ipad> <it|en>`, solo su un simulatore creato apposta: disinstalla Postino dal simulatore, forza la barra di stato pulita e lancia `integration_test/store_screenshots_test.dart` (salta se manca `--dart-define=STORE_SHOTS`), che si ferma se trova già degli Account, collega i due Account demo, apre le cinque schermate e a ognuna stampa `SHOT <nome>`. Lo script cattura con `xcrun simctl io <udid> screenshot`, toglie il canale alfa con `opaque.swift` (App Store Connect rifiuta i PNG con alfa) ed esce con errore se il driver fallisce o manca un'immagine. Il driver gira in debug e nasconde il nastro «DEBUG».
4. Riavviare il server tra un dispositivo e l'altro (lo stato cambia: messaggi letti, Bozza salvata).
5. Guardare ogni immagine: niente dati reali, testo intero, lingua giusta. Poi spegnere server e simulatori e cancellare simulatori e cartella temporanea.

Limiti noti: l'orario dei messaggi è quello vero del momento della cattura (la barra di stato dice 9:41); sull'iPad iOS 27 mostra nella barra di stato il nome dell'app e in basso a destra il controllo di ridimensionamento della finestra, che sono lo schermo reale.
