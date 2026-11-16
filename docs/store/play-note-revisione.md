# Note per i revisori Google Play (inglese)

Testo per **Contenuti dell'app → Accesso all'app** (*App access*): «Tutte o alcune funzionalità sono limitate», poi **+ Aggiungi nuove istruzioni**. Le credenziali dell'account demo **non stanno nel repo**: i segnaposto `<…>` li compila il titolare in Console, vedi [play-checklist-titolare.md](play-checklist-titolare.md). La casella demo è la stessa della revisione Apple ([note-revisione.md](note-revisione.md)). Il testo è in inglese perché lo legge il revisore; i nomi dei comandi sono quelli di `lib/i18n/en.i18n.json`.

## Campi

| Campo della Console | Valore |
|---|---|
| Nome delle istruzioni | `IMAP demo mailbox` |
| Nome utente, email o numero di telefono | `<DEMO_EMAIL>` |
| Password | `<DEMO_PASSWORD>` |
| Altre informazioni necessarie | il blocco sotto |

## Altre informazioni (incollare)

```
Postino is an email client. It has NO Postino account and NO sign-in of its own: the user connects the mailboxes they already have. There is no developer backend; the app talks directly to the user's mail providers.

HOW TO SIGN IN WITH THE DEMO MAILBOX
1. On first launch, tap "Other IMAP" (or menu > Settings > "Add Account" > "IMAP").
2. Enter the email address and password above. The servers are found automatically. If not, tap "Set up the servers manually":
   IMAP: <IMAP_HOST>, port <IMAP_PORT>, SSL/TLS
   SMTP: <SMTP_HOST>, port <SMTP_PORT>, <SSL/TLS or STARTTLS>
3. Tap "Connect". Mail appears in the unified Inbox within a few seconds. No one-time code or MFA is needed.
Please do not remove the demo account: "Remove Account" only deletes the local copy on the device.

GMAIL
"Connect Gmail" uses Google OAuth. Until our Google OAuth verification (restricted Gmail scope) is complete, Google shows "Google hasn't verified this app" on its own sign-in screen. For this reason the demo mailbox is IMAP; a Gmail account is not needed to review the app.

IMMEDIATE NOTIFICATIONS (foreground service, specialUse)
Menu > Settings > Device settings > "Immediate notifications" (off by default). When the user turns it on, a foreground service keeps the IMAP IDLE connection open so new mail is notified in real time with the app closed; a persistent "Postino is listening" notification stays visible. Postino then opens the system battery optimization settings so the user can exclude it by hand; Postino does not request the REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission. Turning the switch off stops the service. The demo video is linked in the foreground service declaration.

CAMERA
Used only by "Scan the QR" (Settings > Sync to... > pairing) to read a pairing code shown by another of the user's devices. The image is decoded on the device and never leaves it. It needs a Google account for settings sync, so it cannot be tried with the IMAP demo mailbox.

ON-DEVICE AI (optional)
"Automatic labels" works only with Gmail labels. The model (about 165 MB) is downloaded once from Hugging Face when the user turns the feature on, and runs entirely on the device. It is a data file (model weights), not executable code.

NO ADS, NO TRACKING, NO PURCHASES, NO UPDATES OUTSIDE GOOGLE PLAY
No ads, no analytics, no automatic crash collection, no in-app purchases. Mail and credentials stay on the device in an encrypted database. This Google Play build does not check for or download updates from anywhere else.

Privacy policy: https://postino.camillobucciarelli.dev/en/privacy.html
Contact: camillo@bucciarelli.dev
```

## Note per il titolare (non incollare)

- Verificati in `lib/i18n/en.i18n.json`: «Other IMAP», «Add Account», «Set up the servers manually», «Connect», «Device settings», «Immediate notifications», «Postino is listening», «Sync to…», «Scan the QR», «Automatic labels». Il percorso «Settings > Add Account» va riprovato sulla build Play.
- La frase sulla schermata dell'ottimizzazione batteria vale solo quando la fetta 1 di #345 è unita; prima di incollarla, verificarla sulla build `store`.
- I revisori Google possono collegarsi da Paesi diversi: provare che la casella demo non blocchi gli accessi dall'estero.
