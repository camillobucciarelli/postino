# Checklist del titolare

Azioni che solo il titolare può fare in App Store Connect (#326). Spuntare ogni voce prima dell'invio a revisione. Dipendenze: #323 (iOS), #324 (pagina di supporto), #325 (variante Mac App Store) devono essere unite, e la build caricata.

## Prima di aprire App Store Connect

- [ ] #323, #324 e #325 unite; l'URL della pagina di supporto (#324) sostituisce quello provvisorio in [scheda-it.md](scheda-it.md) e [scheda-en.md](scheda-en.md).
- [ ] Account demo creato (vedi sotto) e provato in Postino, sul simulatore o su un dispositivo.
- [ ] Screenshot prodotti secondo [screenshot.md](screenshot.md) e messi in `docs/store/screenshot/` (o caricati direttamente).

## Scheda e dati dell'app

- [ ] **Nuova app**: nome `Postino`, lingua principale Italiano, bundle ID uguale per iOS e macOS (acquisto universale, #325), SKU a scelta. Se il nome è già preso, scegliere una variante e allineare scheda e sottotitolo.
- [ ] Incollare la scheda **italiana** e quella **inglese** (nome, sottotitolo, testo promozionale, descrizione, parole chiave) da [scheda-it.md](scheda-it.md) e [scheda-en.md](scheda-en.md); URL di supporto, marketing e informativa privacy; copyright; categoria **Produttività**.
- [ ] Caricare gli screenshot iPhone 6.9", iPad 13" e Mac, per ogni lingua.
- [ ] **App Privacy**: rispondere come in [app-privacy.md](app-privacy.md), compresa la scelta sulla Segnalazione di un problema; l'esito deve coincidere con `PrivacyInfo.xcprivacy`.
- [ ] **Questionario sull'età**: [app-privacy.md](app-privacy.md), sezione 5; annotare la fascia risultante.
- [ ] Informativa privacy: https://postino.camillobucciarelli.dev/privacy.html (it) e `/en/privacy.html` (en).

## Account demo e note di revisione

- [ ] Creare una casella IMAP/SMTP dedicata (non Gmail: #42) con password e senza verifica in due passaggi. Riempirla con alcune decine di messaggi d'esempio non personali: mittenti diversi, uno non letto, uno con allegato, uno HTML con immagini remote, uno con Stella.
- [ ] Facoltativo: un account Outlook.com personale dedicato alla revisione, senza verifica in due passaggi.
- [ ] Verificare che le credenziali funzionino da una rete diversa dalla propria e che l'account non venga bloccato per accessi dall'estero (i revisori Apple sono negli Stati Uniti).
- [ ] In *App Review Information*: *Sign-in required* su Sì, nome utente e password dell'account demo; incollare [note-revisione.md](note-revisione.md) nel campo note sostituendo ogni `<…>`. **Le credenziali non vanno nel repo.**
- [ ] Contatto di revisione: nome, telefono ed email del titolare.

## Conformità e commercio

- [ ] **Stato di trader (DSA)**: il Digital Services Act dell'UE obbliga a dichiararsi *trader* o *non trader* per distribuire nell'UE. Se Postino resta gratuito e non è un'attività commerciale, si può dichiarare non trader; se c'è un'attività professionale (o il caffè di «Sostieni il progetto» è visto come tale), si dichiara trader e Apple pubblica nome, indirizzo e contatti sulla scheda dei Paesi UE. Decisione del titolare: non la prendo io.
- [ ] **Prezzo e Paesi**: scegliere il prezzo (gratis o a pagamento) e i Paesi di distribuzione. Postino non ha acquisti in-app. Controllare che tra i Paesi scelti non ce ne siano dove la scheda richiede documenti aggiuntivi.
- [ ] **Export compliance**: rispondere alle domande di Apple sulla crittografia in modo coerente con la decisione di #323 (`ITSAppUsesNonExemptEncryption` in `ios/Runner/Info.plist`, oggi `false`) e con #325 per il Mac. L'app usa SQLCipher, AES/HMAC sugli allegati (`attachment_crypto.dart`) e TLS: la risposta giusta dipende dalla lettura che #323 documenta; non cambiare la risposta qui senza cambiare il plist.
- [ ] Accordi, fiscalità e conti bancari di App Store Connect firmati e completi (richiesti anche per un'app gratuita nei Paesi con obblighi fiscali; per un'app a pagamento sempre).
- [ ] Percentuale di diritti dei contenuti: nessun contenuto di terzi da dichiarare.

## Invio

- [ ] Scegliere la build (iOS e macOS) caricata dalla pipeline e verificare che sia quella della versione che si vuole pubblicare.
- [ ] Rileggere la scheda: nessuna funzione descritta che non esista nella build scelta (vedi «Affermazioni non verificate» in [README.md](README.md)).
- [ ] Scegliere il rilascio (manuale o automatico dopo l'approvazione).
- [ ] **Invio a revisione** (*Add for Review* → *Submit to App Review*).
- [ ] Dopo l'approvazione: link allo Store sul sito e `ios/latest/version.json` (fuori da #326, vedi #323).
