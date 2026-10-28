---
status: Accettato
date: 2026-10-27
updated: 2026-10-28
---

# Crittografia: OpenPGP e S/MIME in lettura e scrittura

Postino supporterà sia OpenPGP (PGP/MIME) sia S/MIME, in lettura (verifica, decifratura) e in scrittura (firma, cifratura), nella milestone v2: la crittografia è stata spostata dopo la v1 per far uscire prima la posta di base. Servono entrambi perché i due mondi non si parlano: S/MIME è quello di aziende e pubbliche amministrazioni, OpenPGP quello di comunità tecniche e giornalisti. Le scelte sotto sono tutte difficili da cambiare, perché toccano formato dei messaggi, chiavi dell'utente e contenuto del DB locale.

## Decisione

- **S/MIME** tramite l'API CMS di OpenSSL libcrypto, chiamata da Dart FFI. libcrypto è inclusa nell'app su iOS, macOS e Windows (e su Android se serve), di sistema su Linux. Si importano i certificati `.p12`.
- **OpenPGP** tramite il plugin Flutter `openpgp` (nucleo in Go). Il livello PGP/MIME (`multipart/signed`, `multipart/encrypted`, canonicalizzazione CRLF) lo scriviamo noi sopra il MIME di enough_mail.
- **Chiavi private**: si importano a mano su ogni dispositivo (`.asc` / `.p12`), stanno solo nel portachiavi del sistema operativo e non si sincronizzano mai. Postino può generare una chiave PGP; prima di poterla usare va esportata in un file `.asc` protetto da passphrase, che è anche l'unico backup ([Backup e recupero delle Chiavi](https://github.com/camillobucciarelli/postino/issues/17)). Postino non offre recupero per le chiavi importate e non genera certificati di revoca.
- **Chiavi degli altri**, trovate automaticamente: i certificati S/MIME si raccolgono dai messaggi firmati ricevuti; le chiavi PGP da header Autocrypt, chiavi allegate e ricerca WKD sul dominio del destinatario. Fiducia al primo uso (trust on first use).
- **Scrittura di un messaggio**: interruttori Firma e Cifra, spenti di default, accesi in automatico quando si risponde a un messaggio firmato o cifrato. Cifra resta disattivato finché non si conoscono le chiavi di tutti i destinatari.
- **Contenuto decifrato** salvato nel DB locale SQLCipher (ADR 0003), così è ricercabile e si apre subito.

## Alternative considerate

- **CMS in puro Dart** su `pkcs7` + `pointycastle`: ASN.1 e CMS scritti a mano, 4-6 settimane di lavoro e rischio di sicurezza alto. Scartata.
- **`dart_pg`** (OpenPGP in puro Dart): poca adozione, nessun rilascio da 18 mesi. Scartata.
- **Chiavi sincronizzate su Drive, cifrate**: la sicurezza si ridurrebbe a una passphrase più l'account Google. Scartata: una chiave privata non lascia il dispositivo su cui è stata importata.
- **Decifrare a ogni apertura**: più sicuro sulla carta, ma niente ricerca e apertura lenta. Scartata: il DB è già cifrato (ADR 0003).

## Conseguenze

- Il peso della build nativa cresce (Go e OpenSSL).
- Test di interoperabilità obbligatori, con messaggi prodotti da GnuPG e da OpenSSL/Thunderbird.
- Validazione della catena dei certificati e revoca sono la parte più difficile.
- Stima: diverse settimane di lavoro.
- La validazione delle catene S/MIME e la revoca seguono [Validazione delle catene S/MIME e revoca](https://github.com/camillobucciarelli/postino/issues/7).
