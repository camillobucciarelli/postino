---
status: Accettato
date: 2026-11-15
---

# Crittografia ed export compliance Apple: `ITSAppUsesNonExemptEncryption` = YES

Con la pubblicazione sull'App Store (#323) la dichiarazione `ITSAppUsesNonExemptEncryption` in `ios/Runner/Info.plist` non è più una formalità di TestFlight. Era `false`; diventa `true`. Il 16/11/2026 il titolare ha escluso la Francia dalla distribuzione: la decisione è nelle conseguenze.

## Cosa usa Postino

Nessuna di queste crittografie è quella del sistema operativo Apple:

- **SQLCipher** (AES-256 e HMAC, ADR 0003): il database, compilato dal pacchetto `sqlite3` con `source: sqlcipher` (`pubspec.yaml`).
- **pointycastle** AES e HMAC (`lib/core/data/attachment_crypto.dart`): la cache degli allegati e i log.
- **TLS di Dart** (`dart:io` `SecureSocket`/`HttpClient`): IMAP, SMTP e le API dei Provider. Dart lo implementa con BoringSSL dentro il motore Flutter, non con `URLSession`/Network.framework; del sistema usa solo i certificati radice.

Sono tutti algoritmi standard (AES, SHA/HMAC, TLS), pubblicati da enti di standardizzazione: nessuna crittografia proprietaria.

## Cosa dice Apple

- *Complying with Encryption Export Regulations* (https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations): la chiave vale NO se l'app, comprese le librerie che collega, non usa crittografia o usa solo forme esenti dai requisiti di documentazione; altrimenti YES. Di solito è esente la crittografia del sistema operativo (per esempio HTTPS con `URLSession`), non quella propria.
- *Export compliance documentation for encryption* (https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption), tabella per algoritmo:
  - crittografia limitata a quella del sistema operativo Apple → nessuna documentazione;
  - **algoritmo standard non fornito dal sistema operativo Apple → la dichiarazione di crittografia francese**, richiesta solo se l'app è distribuita in Francia;
  - algoritmo proprietario → CCATS e dichiarazione francese.

Postino è nel secondo caso. Distribuita in Francia richiede documentazione, quindi non è nella forma "esente": il valore è YES. Con NO la dichiarazione sarebbe falsa per la distribuzione in Francia.

## Conseguenze

- App Store Connect chiede le domande sulla crittografia a ogni build caricata, TestFlight compreso: finché non hanno risposta la build resta in «Missing Compliance» e non arriva ai tester. La pipeline (`release.yml`) carica comunque; la risposta si dà a mano in App Store Connect.
- Il 16/11/2026 il titolare ha escluso la **Francia** dalla distribuzione (174 Paesi su 175, impostato in App Store Connect), per non presentare la dichiarazione di crittografia francese. Il valore resta `true` (vedi sotto).
- Nessuna dichiarazione francese da caricare: la tabella di Apple la richiede solo per la distribuzione in Francia, e quindi per Postino non serve alcun documento. Senza documento approvato Apple non assegna un `ITSEncryptionExportComplianceCode`: le domande sulla crittografia restano da rispondere in App Store Connect per ogni build, a mano (da confermare alla prima build caricata dopo l'esclusione).
- Rapporto annuale di autoclassificazione al governo USA: secondo la prima pagina serve a chi dichiara forme esenti, e non serve a chi usa crittografia non esente e fornisce la documentazione ad Apple. Escludendo la Francia non si fornisce documentazione: da verificare se Postino ricade nel primo caso. Non verificato.
- La variante Mac App Store (#325) usa le stesse librerie: vale la stessa conclusione per la sua `Info.plist`.
- Perché resta YES anche senza la Francia: SQLCipher, pointycastle e il TLS di Dart restano crittografia non fornita dal sistema operativo Apple. Escludere la Francia cambia solo quale documentazione la tabella chiede, non cosa l'app usa; il valore NO non è stato adottato.
- **Riaprire la Francia** richiede la dichiarazione di crittografia francese (ANSSI) caricata in App Store Connect (App Information → App Encryption Documentation) e, una volta approvata, il codice di Apple da mettere in `Info.plist` come `ITSEncryptionExportComplianceCode`. Poi aggiungere la Francia ai Paesi di distribuzione.
- Un cambio di librerie (per esempio TLS del sistema al posto di quello di Dart) non basta a tornare a NO finché restano SQLCipher e pointycastle.
