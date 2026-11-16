# Checklist del titolare · Google Play

Azioni che solo il titolare può fare nella Play Console e nel repo (#345). Le fette 1 (variante «store») e 2 (job `android-store` in `release.yml`) di #345 vanno unite prima del primo caricamento. La checklist Apple è in [checklist-titolare.md](checklist-titolare.md).

## 1. Account e app

- [ ] Account sviluppatore **personale** verificato (identità, contatto). Gli account personali creati dopo il 13/11/2023 devono fare un test chiuso prima della produzione (sezione 5).
- [ ] **Crea app**: nome `Postino Mail`, lingua predefinita **Italiano – it-IT**, tipo **App**, **Senza costi** (non si può più rendere a pagamento dopo), e le dichiarazioni: norme del programma per gli sviluppatori, **leggi statunitensi sull'esportazione**, termini di Play App Signing ([crea app](https://support.google.com/googleplay/android-developer/answer/9859152)).
- [ ] Pacchetto: `com.cbucciarelli.postino`, lo stesso dell'APK del sito. Si fissa col primo AAB e non cambia più.

## 2. Firma: Play App Signing con la chiave attuale come chiave di upload

Decisione di #345: la chiave che firma l'APK del sito diventa la **chiave di upload**; Play firma gli APK per gli utenti con la sua **chiave di firma dell'app**. Fonte: [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756).

- [ ] Al primo AAB la Console propone una chiave generata da Google (dal 2026 di default «ibrida, quantum-ready»). **Lasciarla**: è il caso consigliato da Google (chiave di upload e chiave di firma diverse). Conseguenza: gli APK installati da Play hanno una firma diversa dall'APK del sito, quindi **non ci si aggiorna da uno all'altro**; per passare da una fonte all'altra si disinstalla (gli Account si ricollegano o arrivano dalle Impostazioni sincronizzate).
- [ ] Alternativa, solo se il titolare vuole che APK del sito e Play si aggiornino a vicenda: prima che una release arrivi in test aperto o produzione, scegliere «usa la chiave di un'altra app / carica una chiave esportata» e caricare la chiave attuale come chiave di firma (procedura in Console, strumento PEPK). Allora serve una **chiave di upload nuova**, diversa, per la pipeline. Non è la decisione di #345: richiede di rivedere la fetta 2.
- [ ] Il primo AAB, firmato con la chiave attuale (keystore `ANDROID_KEYSTORE_PATH`), definisce la chiave di upload. Controllare in **Test e rilascio → Configurazione → Integrità dell'app → Firma dell'app** che il certificato di upload abbia la SHA-256 della chiave attuale (`keytool -list -v -keystore <keystore>`).
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
- [ ] Al tag successivo controllare che la run carichi l'AAB sulla traccia interna.

## 5. Test chiuso: 12 tester per 14 giorni

Fonte: [requisiti di test per i nuovi account personali](https://support.google.com/googleplay/android-developer/answer/14151465).

- [ ] **Test chiuso** (traccia Alpha o una nuova): promuovere la release dalla traccia interna; Paesi come la sezione 9 di [play-dichiarazioni.md](play-dichiarazioni.md) (Francia esclusa).
- [ ] Tester: una lista email o un Google Group con **almeno 12 persone**, che accettano l'invito dal link di partecipazione e **restano iscritte per 14 giorni di fila**: chi esce e rientra riparte da zero. Meglio reclutarne 15 o più.
- [ ] I tester con Gmail superano il limite di 100 utenti del progetto OAuth in modalità test? Finché #42 (verifica OAuth di Google) non è chiusa, ogni tester Gmail va aggiunto agli utenti di test della schermata di consenso, oppure prova con una casella IMAP, iCloud o Microsoft.
- [ ] Dopo 14 giorni: **Dashboard → Richiedi l'accesso alla produzione** e rispondere alle domande sul test (come sono stati reclutati i tester, che feedback, cosa è cambiato).

## 6. Scheda e «Contenuti dell'app»

- [ ] Scheda italiana e inglese da [play-scheda-it.md](play-scheda-it.md) e [play-scheda-en.md](play-scheda-en.md); categoria, contatti, icona e grafica in evidenza da [play-scheda-it.md](play-scheda-it.md).
- [ ] Screenshot del telefono da `docs/store/screenshot/android/<lingua>/` ([screenshot.md](screenshot.md)), controllati a occhio.
- [ ] **Aggiornare l'informativa sul sito** prima di dichiarare la Sicurezza dei dati: credenziali sincronizzate cifrate (ADR 0019), nessun controllo degli aggiornamenti nella build Play, fotocamera per il QR (sezione 1 di [play-dichiarazioni.md](play-dichiarazioni.md)).
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
