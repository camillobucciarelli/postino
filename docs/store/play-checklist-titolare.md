# Checklist del titolare · Google Play

Azioni che solo il titolare può fare nella Play Console e nel repo (#345). Le fette 1 (variante «store») e 2 (job `android-store` in `release.yml`) di #345 vanno unite prima del primo caricamento. La checklist Apple è in [checklist-titolare.md](checklist-titolare.md).

## 1. Account e app

- [ ] Account sviluppatore **personale** verificato (identità, contatto). Gli account personali creati dopo il 13/11/2023 devono fare un test chiuso prima della produzione (sezione 5).
- [ ] **Crea app**: nome `Postino Mail`, lingua predefinita **Italiano – it-IT**, tipo **App**, **Senza costi** (non si può più rendere a pagamento dopo), e le dichiarazioni: norme del programma per gli sviluppatori, **leggi statunitensi sull'esportazione**, termini di Play App Signing ([crea app](https://support.google.com/googleplay/android-developer/answer/9859152)).
- [ ] Pacchetto: `com.cbucciarelli.postino`, lo stesso dell'APK del sito. Si fissa col primo AAB e non cambia più.

## 2. Firma: la chiave dell'APK del sito anche su Play

Decisione del titolare del 16/11/2026 (#345, [ADR 0023](../adr/0023-variante-google-play.md)): Play firma gli APK per gli utenti con la **stessa chiave dell'APK del sito**, così le due build si aggiornano a vicenda. La stessa chiave resta anche **chiave di upload** della pipeline. Fonte: [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756).

- [ ] Prima che una release arrivi in test aperto o produzione: Actions → **Play key export** → *Run workflow* su `main` (`gh workflow run play-key-export.yml --ref main`). Scaricare l'artifact `play-key-export` entro un giorno: lo ZIP dell'artifact contiene `output.zip`, cifrato con la chiave pubblica di Play (lo legge solo Google).
- [ ] **Test e rilascio → Configurazione → Integrità dell'app → Firma dell'app → Change key → Export and upload a key from Java keystore**: caricare `output.zip`, poi cancellarlo dal Mac. Se la Console propone una chiave di upload nuova, **non** generarla: la pipeline firma con la chiave attuale.
- [ ] Controllare nella stessa pagina che il certificato della chiave di firma **e** quello della chiave di upload abbiano la SHA-256 `47:03:4A:D7:65:75:3A:E5:27:8C:6C:09:F6:5E:E8:5F:E7:6B:26:56:85:9C:04:AC:78:54:2D:8A:8D:12:1F:04`.
- [ ] Dopo il primo download da Play (test interno): installare sopra l'APK del sito, e viceversa, senza disinstallare.
- [ ] Google OAuth: Postino su Android usa un client di tipo iOS con schema `com.googleusercontent.apps.<id>`, quindi la SHA-1 di firma non dovrebbe contare (#345). Verificarlo in Google Cloud Console (Credenziali) e con un accesso Gmail dalla build scaricata da Play nel test interno.

## 3. Primo caricamento manuale

- [ ] Costruire l'AAB della variante `store` firmato con la chiave di upload (comando della fetta 2, `flutter build appbundle --flavor store`) oppure scaricarlo dalla run di `release.yml`.
- [ ] **Test e rilascio → Test → Test interno → Crea nuova release**, caricare l'AAB, note di rilascio, salvare e pubblicare sulla traccia interna. Aggiungere sé stessi come tester interno.
- [ ] Perché a mano: la pipeline carica con l'API Play Developer, e l'app deve già esistere con un primo AAB (decisione di #345). **Non verificato** su una pagina di Google che l'API rifiuti il primo caricamento; il primo a mano è comunque il percorso documentato per creare l'app.

## 4. API Play Developer per la pipeline

Fonte: [Getting started](https://developers.google.com/android-publisher/getting_started). Non serve più collegare l'account sviluppatore a un progetto Google Cloud.

- [ ] In Google Cloud (un progetto qualunque del titolare, anche quello dell'OAuth o uno nuovo): abilitare **Google Play Android Developer API**.
- [ ] Creare un **service account** e una chiave JSON. La chiave non va nel repo.
- [ ] Play Console → **Utenti e autorizzazioni → Invita nuovi utenti**: l'email del service account, accesso **solo a Postino Mail**, permessi **Rilascia sulle tracce di test** (e *Visualizza le informazioni dell'app*). Niente produzione: la promozione la fa il titolare a mano.
- [ ] GitHub → Settings → Secrets and variables → Actions: il segreto con il JSON (nome fissato dalla fetta 2 in `release.yml`) e la variabile `PLAY_STORE` = `true`. Senza la variabile il job `android-store` non parte.
- [ ] Al tag successivo controllare che la run carichi l'AAB sulla traccia della variabile `GOOGLE_PLAY_TRACK` (di default quella interna; `alpha` è il test chiuso) con lo stato di `GOOGLE_PLAY_RELEASE_STATUS` (`completed` o `draft`).

## 5. Test chiuso: 12 tester per 14 giorni

Fonte: [requisiti di test per i nuovi account personali](https://support.google.com/googleplay/android-developer/answer/14151465).

- [ ] **Test chiuso** (traccia Alpha o una nuova): con `GOOGLE_PLAY_TRACK` = `alpha` la release arriva direttamente sul test chiuso; promuoverla dalla traccia interna serve solo con il default (`internal`); Paesi come la sezione 9 di [play-dichiarazioni.md](play-dichiarazioni.md) (Francia esclusa).
- [ ] Tester: una lista email o un Google Group con **almeno 12 persone**, che accettano l'invito dal link di partecipazione e **restano iscritte per 14 giorni di fila**: chi esce e rientra riparte da zero. Meglio reclutarne 15 o più.
- [ ] I tester con Gmail superano il limite di 100 utenti del progetto OAuth in modalità test? Finché #42 (verifica OAuth di Google) non è chiusa, ogni tester Gmail va aggiunto agli utenti di test della schermata di consenso, oppure prova con una casella IMAP, iCloud o Microsoft.
- [ ] Dopo 14 giorni: **Dashboard → Richiedi l'accesso alla produzione** e rispondere alle domande sul test (come sono stati reclutati i tester, che feedback, cosa è cambiato).

## 6. Scheda e «Contenuti dell'app»

- [ ] Scheda italiana e inglese da [play-scheda-it.md](play-scheda-it.md) e [play-scheda-en.md](play-scheda-en.md); categoria, contatti, icona e grafica in evidenza da [play-scheda-it.md](play-scheda-it.md).
- [ ] Screenshot del telefono da `docs/store/screenshot/android/<lingua>/` ([screenshot.md](screenshot.md)), controllati a occhio.
- [ ] **Aggiornare l'informativa sul sito** prima di dichiarare la Sicurezza dei dati: credenziali sincronizzate cifrate (ADR 0019), nessun controllo degli aggiornamenti nella build Play, fotocamera e ML Kit di Google per il QR (sezione 1 di [play-dichiarazioni.md](play-dichiarazioni.md)).
- [ ] Norme sulla privacy, Annunci, Accesso all'app, Classificazione dei contenuti, Pubblico di destinazione, Sicurezza dei dati, ID pubblicità, App governative, Funzionalità finanziarie, App per la salute, Servizi in primo piano: come in [play-dichiarazioni.md](play-dichiarazioni.md).
- [ ] Video dei servizi in primo piano registrato secondo la scaletta di [play-dichiarazioni.md](play-dichiarazioni.md), caricato su YouTube non in elenco, link nella dichiarazione.

## 7. Casella demo per i revisori

- [ ] La stessa casella IMAP della revisione Apple ([checklist-titolare.md](checklist-titolare.md)), non Gmail (#42), senza verifica in due passaggi, con alcune decine di messaggi d'esempio non personali.
- [ ] **Contenuti dell'app → Accesso all'app**: compilare come [play-note-revisione.md](play-note-revisione.md), sostituendo i segnaposto `<…>`. **Le credenziali non vanno nel repo.**

## 8. Prima della produzione

- [ ] Paesi: tutti tranne la Francia, sulla produzione e su ogni traccia di test.
- [ ] Rileggere la scheda sulla build scelta: nessuna funzione descritta che non esista (vedi [README.md](README.md)).
- [ ] Promuovere la release dal test chiuso alla produzione, con rilascio graduale se si vuole.
- [ ] Dopo la pubblicazione: link a Google Play sul sito (fuori da #345).
