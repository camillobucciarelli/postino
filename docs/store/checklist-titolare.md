# Checklist del titolare

Azioni che solo il titolare può fare in App Store Connect (#326). Spuntare ogni voce prima dell'invio a revisione. Dipendenze: #323 (iOS), #324 (pagina di supporto), #325 (variante Mac App Store) devono essere unite, e la build caricata.

## Prima di aprire App Store Connect

- [x] #323, #324 e #325 unite; l'URL della pagina di supporto (#324) è in [scheda-it.md](scheda-it.md) e [scheda-en.md](scheda-en.md).
- [ ] Account demo creato (vedi sotto) e provato in Postino, sul simulatore o su un dispositivo.
- [ ] Screenshot Mac prodotti secondo [screenshot.md](screenshot.md) (iPhone e iPad già in `docs/store/screenshot/`) e controllati a occhio.

## Scheda e dati dell'app

- [x] **Nuova app** (fatto: «Postino Mail», ID Apple 6831333983): nome `Postino`, lingua principale Italiano, bundle ID uguale per iOS e macOS (acquisto universale, #325), SKU a scelta. Il nome sullo Store è «Postino Mail».
- [x] Incollare la scheda **italiana** e quella **inglese** (nome, sottotitolo, testo promozionale, descrizione, parole chiave) da [scheda-it.md](scheda-it.md) e [scheda-en.md](scheda-en.md); URL di supporto, marketing e informativa privacy; copyright; categoria **Produttività**.
- [ ] Caricare gli screenshot iPhone 6.9", iPad 13" e Mac, per ogni lingua.
- [x] **App Privacy** (pubblicata come «Dati non raccolti»): rispondere come in [app-privacy.md](app-privacy.md), compresa la scelta sulla Segnalazione di un problema; l'esito deve coincidere con `PrivacyInfo.xcprivacy`.
- [x] **Questionario sull'età**: fascia 4+.
- [x] Informativa privacy: https://postino.camillobucciarelli.dev/privacy.html (it) e `/en/privacy.html` (en).

## Account demo e note di revisione

- [ ] Creare una casella IMAP/SMTP dedicata (non Gmail: #42) con password e senza verifica in due passaggi. Riempirla con alcune decine di messaggi d'esempio non personali: mittenti diversi, uno non letto, uno con allegato, uno HTML con immagini remote, uno con Stella.
- [ ] Verificare che le credenziali funzionino da una rete diversa dalla propria e che l'account non venga bloccato per accessi dall'estero (i revisori Apple sono negli Stati Uniti).
- [ ] In *App Review Information*: *Sign-in required* su Sì, nome utente e password dell'account demo. **Le credenziali non vanno nel repo.** Le note di [note-revisione.md](note-revisione.md) sono già incollate (senza il blocco Outlook; macOS con la variante «click»), ma i segnaposto `<…>` dell'account demo vanno sostituiti quando l'account esiste.
- [ ] Contatto di revisione: nome, telefono ed email del titolare.

## Conformità e commercio

- [x] **Stato di trader (DSA)**: non operatore commerciale.
- [x] **Prezzo e Paesi**: gratis; 174 Paesi su 175, **Francia esclusa** (16/11/2026, ADR 0020; condizione dell'export compliance dell'ADR 0022).
- [x] **Export compliance**: `ITSAppUsesNonExemptEncryption` vale `false` (ADR 0022): l'app è esente dal fornire documentazione perché la Francia è esclusa. Non significa che l'app non usa crittografia: SQLCipher, pointycastle e il TLS di Dart ci sono. Il 16/11/2026 il titolare ha compilato in App Store Connect (App Information → App Encryption Documentation) il questionario «Documentazione relativa alla crittografia dell'app» con queste risposte:
  - l'app usa la crittografia: **sì**;
  - algoritmi proprietari (non standard): **no**;
  - algoritmi standard in aggiunta a quelli del sistema operativo Apple: **sì**;
  - distribuzione in Francia: **no**.

  L'esito è «nessun documento richiesto». In App Store Connect non resta registrato alcun documento (la sezione mostra ancora solo «Carica»), ed è quello che ci si aspetta. Per riaprire la Francia serve prima la dichiarazione ANSSI approvata, poi `true` con `ITSEncryptionExportComplianceCode` (ADR 0022). Gli obblighi verso il BIS statunitense (per esempio il rapporto annuale di autoclassificazione) li valuta il titolare: il repo non dà consulenza legale.
- [ ] Accordi, fiscalità e conti bancari di App Store Connect firmati e completi (richiesti anche per un'app gratuita nei Paesi con obblighi fiscali; per un'app a pagamento sempre).
- [x] Diritti sui contenuti: nessun contenuto di terzi.

## Invio

- [ ] Scegliere la build (iOS e macOS) caricata dalla pipeline e verificare che sia quella della versione che si vuole pubblicare.
- [ ] Rileggere la scheda: nessuna funzione descritta che non esista nella build scelta (vedi «Affermazioni non verificate» in [README.md](README.md)).
- [ ] Scegliere il rilascio (manuale o automatico dopo l'approvazione).
- [ ] **Invio a revisione** (*Add for Review* → *Submit to App Review*).
- [ ] Certificati e segreti del Mac App Store nel repository (#325), prima di caricare la build macOS.
- [ ] Dopo l'approvazione: lanciare a mano `ios-version-file.yml` con la versione uscita (variabile `APP_STORE_ID` già impostata), link allo Store sul sito e `ios/latest/version.json` (fuori da #326, vedi #323).
