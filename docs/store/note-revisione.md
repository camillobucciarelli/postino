# App Review notes (inglese)

Testo per il campo **App Review Information → Notes** di App Store Connect. Le credenziali dell'account demo **non stanno nel repo**: i segnaposto `<…>` li compila il titolare in App Store Connect (campi *Sign-in required* / *User name* / *Password* più il blocco delle note), vedi [checklist-titolare.md](checklist-titolare.md). Il testo sotto è in inglese perché lo legge il revisore Apple.

```
Postino is an email client. It has NO Postino account and NO sign-in of its own: the user connects the mailboxes they already have. There is no developer backend; the app talks directly to the user's mail providers.

HOW TO TRY THE APP (demo account)
1. On first launch, tap "Other IMAP" (or "Add Account" > "IMAP" in Settings).
2. Email address: <DEMO_EMAIL>
   Password: <DEMO_PASSWORD>
   The servers are found automatically. If not, tap "Set up the servers manually" and enter:
   IMAP: <IMAP_HOST>, port <IMAP_PORT>, SSL/TLS
   SMTP: <SMTP_HOST>, port <SMTP_PORT>, <SSL/TLS or STARTTLS>
3. Tap "Connect". The demo mailbox contains sample messages; mail appears in the unified Inbox within a few seconds.
4. Things to try: open a message; swipe a row (Archive / Mark as read by default); tap the search icon and type a word, or "from:<sender>"; write a message and tap Send (a short Undo window follows); open Settings > Swipe actions.
The demo account is dedicated to this review and contains no personal data. Please do not remove it: "Remove Account" only deletes the local copy on the device.

GMAIL: "GOOGLE HASN'T VERIFIED THIS APP"
"Connect Gmail" uses Google OAuth. Our Google OAuth verification (restricted Gmail scope) is still in progress, so Google shows the "Google hasn't verified this app" warning on its own sign-in screen. This is a Google screen, not part of Postino, and it does not affect the other providers. For this reason the demo account is IMAP, not Gmail; you do not need a Gmail account to review the app. The warning goes away once Google completes the verification.

ON-DEVICE AI (optional feature)
Postino can assign labels automatically ("Automatic labels"), for Gmail accounts only (IMAP and Outlook accounts use folders, so the feature does not apply to the demo account). The model runs entirely on the device: no message content is sent to any server and there is no cloud AI. The model is NOT bundled: it is downloaded once, the first time the user turns the feature on, from Hugging Face (huggingface.co, about 165 MB on iPhone and iPad; the file is checked against a fixed size and SHA-256). On Wi-Fi it starts right away; on cellular it asks for confirmation first. It cannot be tried with the IMAP demo account; if the reviewer needs to see the download flow, the model is fetched from the URL above. The rest of the app works without the download, and nothing else depends on it.

SETTINGS SYNC ON GOOGLE DRIVE (optional, off by default)
Settings > Sync to... lets the user keep Postino's settings (connected accounts' addresses, colors, swipe actions, automatic-label setup) in sync between their own devices. It stores one small file in the hidden app-data folder (drive.appdata scope) of the user's OWN Google Drive. It never contains mail, passwords or tokens, and there is no Postino server involved. It needs a Google account, so it cannot be tried with the IMAP demo account; the app is fully usable without it.

NO ACCOUNT, NO TRACKING, NO PURCHASES
- No Postino account and no sign-up. Google and Microsoft are only mail providers the user connects, not a way to log in to Postino.
- No ads, no analytics, no tracking, no automatic crash collection, no push-notification server. New-mail notifications are created on the device by checking the mailbox in the background.
- No in-app purchases or subscriptions.
- Mail and credentials stay on the device: the local database is encrypted (SQLCipher) and its key, and the account tokens/passwords, are in the system Keychain.
- "Report a problem" (Settings) only prepares an email draft with an error log that the user reads and decides whether to send.

PRIVACY POLICY
https://postino.camillobucciarelli.dev/en/privacy.html (also linked in the app's Settings).

CONTACT
camillo@bucciarelli.dev
```

## Note per il titolare (non incollare)

- Il passo 1 usa i testi inglesi dell'app («Other IMAP», «Add Account», «Set up the servers manually», «Connect», «Sync to…», «Automatic labels»): verificati in `lib/i18n/en.i18n.json`.
- L'account demo non è Gmail perché, finché #42 non si chiude, il revisore non potrebbe completare l'accesso senza l'avviso di Google.
- Il campo *Sign-in required* di App Store Connect va su **Sì** e porta le credenziali dell'account IMAP.
- Il testo sopra è quello incollato in App Store Connect il 16/11/2026: senza il blocco facoltativo sull'account Outlook, per stare nei 4000 caratteri.
- Il link all'informativa nelle Impostazioni c'è (#323 è unita).

## Variante macOS (incollata nel record macOS)

Stesso testo, con «click» al posto di «tap» e senza i dettagli su iPhone. Il testo esatto incollato è in App Store Connect: qui non è riportato per intero.
