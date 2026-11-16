# Screenshot

**Stato: iPhone, iPad e telefono Android prodotti in italiano e in inglese; Mac mancante; tablet Android non prodotto** (motivi sotto). Tutte le immagini mostrano solo posta finta: due caselle `demo@example.com` e `demo@example.org` su un server locale, mittenti e domini inventati (`example.com`, `example.org`). Nessun Account, posta o dato del titolare; l'app già installata non è stata aperta.

Le immagini sono in `docs/store/screenshot/<piattaforma>/<lingua>/NN-nome.png`: PNG sRGB senza trasparenza, senza cornici di dispositivo (Apple le rifiuta se non sono lo schermo reale), barra di stato alle 9:41 con batteria piena.

| Piattaforma | Lingue | Dimensione (px) | Dispositivo |
|---|---|---|---|
| `iphone` | `it`, `en` | 1320 × 2868 (verticale) | simulatore iPhone 17 Pro Max, iOS 27.0 |
| `ipad` | `it`, `en` | 2064 × 2752 (verticale) | simulatore iPad Pro 13-inch (M5), iOS 27.0 |
| `mac` | — | — | **mancante** |
| `android` | `it`, `en` | 1080 × 1920 (verticale, 9:16) | emulatore Android 16 (API 36, immagine `google_apis` arm64), schermo 1080 × 1920 a 420 dpi |

Per Google Play: da 2 a 8 screenshot per tipo di dispositivo, JPEG o PNG a 24 bit senza alfa, lato lungo al massimo il doppio del corto; con almeno 4 a 1080 × 1920 l'app può comparire nelle promozioni ([asset grafici](https://support.google.com/googleplay/android-developer/answer/9866151)). Per questo l'emulatore è a 9:16 e non a 1080 × 2400 come i telefoni di oggi (rapporto 2,22, oltre il limite). Barra di stato con la *demo mode* di SystemUI (9:41, batteria e Wi-Fi pieni, niente icone di notifica). Gli screenshot tablet non ci sono: nessuna prova dell'app su tablet Android.

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

Limiti noti: su tutti i dispositivi l'orario dei messaggi è quello vero del momento della cattura (la barra di stato dice 9:41); sull'iPad iOS 27 mostra nella barra di stato il nome dell'app e in basso a destra il controllo di ridimensionamento della finestra, che sono lo schermo reale.

## Come rifarli (telefono Android)

Stesso server finto e stesso driver; cambia il dispositivo. Servono anche l'SDK Android (`emulator`, `adb`, `avdmanager`) e un'immagine **`google_apis`** (non `google_apis_playstore`: serve `adb root`). Tutto tocca solo l'emulatore creato apposta.

1. Emulatore dedicato a 9:16:
   ```sh
   avdmanager create avd -n postino-store -k "system-images;android-36;google_apis;arm64-v8a" -d pixel_6
   # in ~/.android/avd/postino-store.avd/config.ini: hw.lcd.width=1080, hw.lcd.height=1920, hw.keyboard=yes
   emulator -avd postino-store -writable-system -no-snapshot -port 5580
   ```
   `hw.keyboard=yes` tiene chiusa la tastiera a schermo nella schermata 05.
2. `tool/store_screenshots/server.sh <it|en> <cartella>` come sopra.
3. CA del server tra i certificati di sistema dell'emulatore. Il TLS di Dart su Android legge `/apex/com.android.conscrypt/cacerts` (Android 14+) oppure `/system/etc/security/cacerts`, con i nomi dell'hash OpenSSL nuovo (`openssl x509 -subject_hash`), non quello vecchio di Java:
   ```sh
   adb -s emulator-5580 root && adb -s emulator-5580 remount   # al primo giro chiede un riavvio: adb reboot, poi di nuovo root e remount
   h=$(openssl x509 -subject_hash -noout -in <cartella>/ca.pem); cp <cartella>/ca.pem <cartella>/$h.0
   adb push <cartella>/$h.0 /system/etc/security/cacerts/
   ```
   Su Android 14+ la cartella `/apex/…` è in sola lettura: dentro lo spazio dei mount di zygote ci si monta sopra un `tmpfs` con i certificati di sistema più la CA, e così ogni app avviata dopo la vede:
   ```sh
   adb shell 'T=/data/local/tmp/cacerts; rm -rf $T; mkdir $T; cp /apex/com.android.conscrypt/cacerts/* /system/etc/security/cacerts/'$h'.0 $T/; chmod 644 $T/*
     for z in $(pidof zygote64 zygote); do nsenter --mount=/proc/$z/ns/mnt -- sh -c "mount -t tmpfs tmpfs /apex/com.android.conscrypt/cacerts && cp $T/* /apex/com.android.conscrypt/cacerts/ && chmod 644 /apex/com.android.conscrypt/cacerts/* && chcon u:object_r:system_file:s0 /apex/com.android.conscrypt/cacerts/*"; done'
   ```
   Il `tmpfs` sparisce a ogni riavvio dell'emulatore o di zygote (anche dopo il cambio di lingua): va rifatto.
4. Su un Mac con chip M4 o successivo l'OpenSSL dentro l'app (quello di SQLCipher) va in crash all'avvio sull'emulatore (`SIGILL` in `_armv8_sve_get_vl_bytes`): `shots_android.sh` spegne il rilevamento delle estensioni della CPU solo per Postino, con `adb shell setprop wrap.com.cbucciarelli.postino OPENSSL_armcap=0` (serve `adb root`; l'app di debug lo permette).
5. Lingua: `adb shell setprop persist.sys.locale it-IT` (o `en-US`), poi `adb reboot` (con `stop`/`start` SystemUI è rimasta senza demo mode e un dialogo «non risponde» è finito negli screenshot), poi `adb root` e di nuovo il `tmpfs` del punto 3.
6. `tool/store_screenshots/shots_android.sh emulator-5580 <it|en>`: rifiuta un seriale che non sia `emulator-*`, disinstalla Postino, inoltra le porte 3993 e 3465 dell'emulatore al Mac (`adb reverse`), accende la demo mode, lancia il driver e cattura con `adb exec-out screencap`; poi toglie l'alfa con `opaque.swift`.
7. Riavviare il server tra una lingua e l'altra. Guardare ogni immagine, poi spegnere server ed emulatore e cancellare l'emulatore (`avdmanager delete avd -n postino-store`) e la cartella.
