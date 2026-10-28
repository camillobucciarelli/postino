# Distribuzione agli invitati senza store

Ticket: #5 (mappa #1). Data ricerca: 2026-10-28. Contesto: ADR 0001 (nessun backend, meno di 100 utenti, client OAuth Google "in produzione non verificato").

Legenda: **[F]** fatto osservato in fonte primaria, **[I]** inferenza, **[R]** raccomandazione.

## Domanda

Come si distribuisce e si aggiorna Postino a pochi invitati su iOS, Android, macOS, Windows e Linux senza store pubblici? Con quali costi, account sviluppatore e meccanismi di aggiornamento (compreso l'auto-update di Flutter desktop)? Come interagisce con il tetto di 100 utenti dell'app Google non verificata?

## Risposta breve

- Apple ($99/anno) copre iOS e macOS: **TestFlight** per iOS, **Developer ID + notarizzazione + Sparkle** per macOS.
- Android: **Google Play, traccia di test interno** ($25 una tantum, max 100 tester, aggiornamenti automatici dal Play Store), non pubblica. L'APK in sideload resta possibile, ma dal 2027 richiede la registrazione dello sviluppatore.
- Windows: installer EXE/MSIX + **WinSparkle** (via `auto_updater`). La firma di codice fidata costa 150–300 $/anno (certificato OV). Azure Artifact Signing (~10 $/mese) **non è disponibile per persone fisiche nell'UE**.
- Linux: **AppImage** su GitHub Releases, con informazioni di aggiornamento zsync. Costo zero.
- Il vero tetto è il limite OAuth Google: **100 nuovi utenti in totale**, contati per Account Google che concede l'accesso, non per persona o dispositivo.

## Tabella per piattaforma

| Piattaforma | Canale consigliato | Account / costo | Sforzo | Aggiornamenti | Limiti chiave |
|---|---|---|---|---|---|
| iOS | TestFlight, gruppo esterno o link pubblico | Apple Developer Program, 99 $/anno | Medio: Beta App Review per il primo build di ogni versione | Notifica e aggiornamento dall'app TestFlight | Build scade dopo **90 giorni**; 10.000 tester esterni; 100 interni |
| iOS (alternativa) | Ad Hoc (IPA + UDID) | stesso account | Alto: raccolta UDID, profili | Manuale (o Firebase App Distribution) | 100 iPhone + 100 iPad per anno di iscrizione |
| Android | Play Console, traccia di test interno | Google Play Console, 25 $ una tantum | Basso | Automatici dal Play Store | Max 100 tester per app (via email) |
| Android (alternativa) | APK firmato da GitHub Releases | Gratis oggi; dal 2027 registrazione ADC (25 $ "Full", o "Limited" gratis per max 20 dispositivi) | Basso oggi, poi crescente | Manuale o con controllo versione in-app | Verifica sviluppatore obbligatoria a livello globale dal 2027 |
| macOS | DMG/ZIP firmato Developer ID, notarizzato, + Sparkle | stesso account Apple (99 $/anno) | Medio: firma + `notarytool` in CI | Sparkle via `auto_updater` (appcast firmato EdDSA) | Senza notarizzazione, da Sequoia l'utente deve sbloccare l'app da Impostazioni > Privacy e sicurezza |
| Windows | Installer EXE (o MSIX) + WinSparkle | Firma: OV 150–300 $/anno; non firmato = gratis | Medio | WinSparkle via `auto_updater` (appcast firmato DSA); per MSIX, file `.appinstaller` | Avvisi SmartScreen anche con firma finché non si accumula reputazione |
| Linux | AppImage su GitHub Releases | Gratis | Basso | Informazioni zsync incorporate + AppImageUpdate (esterno o incluso) | `auto_updater` non supporta Linux |

## Evidenze per piattaforma

### Apple (iOS e macOS)

- [F] Apple Developer Program 99 $/anno, valido per tutte le piattaforme Apple; Enterprise 299 $/anno solo per distribuzione ai dipendenti (non applicabile). https://developer.apple.com/programs/
- [F] TestFlight: build testabile per 90 giorni, fino a 100 tester interni (utenti App Store Connect) e 10.000 esterni; supporta anche macOS (Xcode 13+). https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- [F] I build per gruppi esterni passano dalla TestFlight App Review (completa per il primo build di una versione); è possibile un link pubblico, con un limite di tester configurabile. https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/
- [F] Ad Hoc: 100 dispositivi per famiglia di prodotto per anno di iscrizione. Disabilitare un dispositivo non libera posti. https://developer.apple.com/help/account/devices/devices-overview/
- [F] Senza iscrizione a pagamento ("Personal Team"): 3 dispositivi e app che scadono dopo 7 giorni, quindi inutilizzabile per gli invitati. https://developer.apple.com/support/compare-memberships/
- [F] macOS Sequoia: tolto il bypass con Ctrl-clic; il software non notarizzato va autorizzato in Impostazioni > Privacy e sicurezza. Apple raccomanda la notarizzazione per il software Developer ID. https://developer.apple.com/news/?id=saqachfa
- [I] TestFlight per Mac richiede un'app con App Sandbox (requisito dei build per App Store Connect). Un client di posta con tray e connessioni persistenti può funzionare in sandbox, ma Developer ID + Sparkle evita il vincolo e la scadenza a 90 giorni. Da verificare quando si configura il target macOS.

### Android

- [F] Test interno su Play: max 100 tester per app tramite liste email; il build arriva in pochi minuti; i test interni "potrebbero non essere soggetti" alle revisioni standard. https://support.google.com/googleplay/android-developer/answer/9845334
- [I] Il requisito "12 tester per 14 giorni" degli account personali creati dopo il 13/11/2023 riguarda il passaggio in **produzione**, non il test interno (la pagina rimanda a answer/14151465, non verificata qui). Postino non va in produzione, quindi non dovrebbe applicarsi.
- [F] Verifica sviluppatore Android: dal 30/09/2026 solo in Brasile, Indonesia, Singapore e Tailandia; **dal 2027 estesa a livello globale** a tutte le app sui dispositivi certificati. Account "Full distribution" nell'Android Developer Console a 25 $; account "Limited distribution" gratuito per max 20 dispositivi; le installazioni via ADB sono esenti; il "flusso avanzato" per utenti esperti prevede modalità sviluppatore e un'attesa di 24 ore. https://developer.android.com/developer-verification e https://developer.android.com/developer-verification/guides/faq
- [I] Le app distribuite su Play vengono registrate automaticamente ("Google Play registra automaticamente il 99% delle app"), quindi la traccia interna risolve anche la verifica del 2027.

### Windows

- [F] Opzioni di firma fuori dallo Store (pagina aggiornata il 29/08/2026): Azure Artifact Signing ~9,99 $/mese, ma **persone fisiche solo USA e Canada** (organizzazioni anche UE/UK); OV 150–300 $/anno con chiave su HSM/token; EV non evita più SmartScreen dal 2024; un certificato self-signed blocca l'installazione salvo installare il certificato come radice fidata. Con qualsiasi firma, SmartScreen avvisa finché il publisher non accumula reputazione. https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options
- [F] MSIX installato tramite file `.appinstaller` ottiene aggiornamenti automatici da un URI (controllo all'avvio, `HoursBetweenUpdateChecks`, `ShowPrompt`), su Windows 10 2004+ e Windows 11. https://learn.microsoft.com/en-us/windows/msix/app-installer/auto-update-and-repair--overview
- [I] Per installare un MSIX serve una firma fidata dal dispositivo: senza un certificato acquistato, MSIX costringe ogni invitato a importare un certificato radice. Un installer EXE non firmato invece si installa dopo "Esegui comunque" di SmartScreen. Per meno di 100 persone conosciute, l'EXE non firmato + WinSparkle è il compromesso più economico.

### Linux

- [F] Le informazioni di aggiornamento sono incorporate nell'AppImage (`appimagetool -u`, stringa `zsync|URL`) e si accompagnano a un file `.zsync`. AppImageUpdate scarica solo i delta; l'app può includerlo e invocarlo (`AppImageUpdate $APPIMAGE`) oppure usare `libappimageupdate`. https://docs.appimage.org/packaging-guide/optional/updates.html
- [I] Flatpak senza Flathub richiede di ospitare un repository OSTree firmato: più lavoro, senza vantaggi per questo pubblico. Flathub sarebbe uno store pubblico, escluso da ADR 0001.

### Auto-update Flutter desktop

- [F] Il pacchetto `auto_updater` (leanflutter, v1.0.0) supporta **macOS (Sparkle) e Windows (WinSparkle)**, non Linux. Usa un appcast RSS condiviso (`sparkle:os`) con firme EdDSA (macOS) e DSA (Windows); perdere la chiave privata Windows impedisce gli aggiornamenti. https://pub.dev/packages/auto_updater
- [I] Ultimo rilascio circa 24 mesi fa: manutenzione da valutare con `supermatt:dependency-vetting` prima di adottarlo. In alternativa, si integrano Sparkle e WinSparkle direttamente lato nativo.

## Interazione con il tetto OAuth Google (100 utenti)

- [F] Un'app non verificata con scope sensibili o riservati mostra la schermata "app non verificata" ed è limitata a **"100 new users in total"** finché non viene verificata; non è documentato alcun reset (le quote possono essere regolate in base a reputazione e rischio). https://support.google.com/cloud/answer/7454865
- [F] Gli scope sensibili o riservati richiedono la verifica per uscire dal limite; gli scope riservati richiedono una riverifica annuale. https://support.google.com/cloud/answer/13463073
- [I] Il limite conta **gli Account Google che concedono l'accesso**, non le persone né le installazioni: un invitato con due Gmail consuma due posti. Non sembra che la revoca liberi un posto ("in totale"). Il budget reale di invitati Gmail è quindi < 100 e va contato per Account.
- [I] I canali di distribuzione hanno limiti coerenti o più larghi (Play interno 100, TestFlight 10.000, Ad Hoc 100 per famiglia): **il collo di bottiglia è OAuth, non la distribuzione.** Gli Account Outlook e IMAP non consumano posti Google.
- [I] La TestFlight App Review vedrà la schermata Google "non verificata" al login: rischio di rifiuto da mitigare fornendo un account demo IMAP nelle note di revisione.

## Raccomandazione [R]

1. **Account**: Apple Developer Program (99 $/anno) e Google Play Console (25 $ una tantum). Nessun certificato Windows all'inizio.
2. **iOS**: TestFlight con gruppo esterno, inviti via email (meglio di un link pubblico, per controllare chi consuma posti OAuth). CI che pubblica un build almeno ogni ~80 giorni, altrimenti il build scade.
3. **Android**: traccia di test interno su Play (100 tester, aggiornamenti automatici, registrazione automatica per la verifica del 2027).
4. **macOS**: Developer ID + notarizzazione + Sparkle tramite `auto_updater`, DMG su GitHub Releases.
5. **Windows**: installer EXE non firmato + WinSparkle tramite `auto_updater`, con istruzioni "Esegui comunque". Rivalutare un certificato OV se gli avvisi SmartScreen creano attrito.
6. **Linux**: AppImage con informazioni zsync su GitHub Releases; voce di menu "Cerca aggiornamenti" che invoca AppImageUpdate incluso.
7. **Un solo registro degli invitati**: contare gli Account Google autorizzati, non le persone.

Costo ricorrente stimato: 99 $/anno (+25 $ una tantum); +150–300 $/anno se si firma per Windows.

## Punti aperti

- Gli appcast e gli artefatti devono stare su un URL pubblico (GitHub Releases di un repo pubblico, oppure hosting statico separato se il repo resta privato)?
- Una ditta individuale o partita IVA italiana conta come "organizzazione UE" per Azure Artifact Signing (~10 $/mese)? Se sì, è più economico dell'OV.
- TestFlight per macOS richiede la sandbox: confermare se è compatibile con tray, keychain e DB cifrato (ADR 0003). Altrimenti si resta su Developer ID.
- Manutenzione di `auto_updater` (v1.0.0, circa 24 mesi senza rilasci) da verificare prima di adottarlo.
- Il requisito Play "12 tester / 14 giorni" non è stato verificato per la sola traccia interna (answer/14151465).
- Il conteggio esatto del tetto OAuth (la revoca libera posti? gli utenti di test contano?) non è documentato: monitorarlo nella Google Cloud Console.
