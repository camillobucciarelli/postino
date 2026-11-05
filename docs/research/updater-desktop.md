# Updater desktop: `auto_updater` o Sparkle nativo

Ticket: #118 (spec #28, commento «Passo 2» del 2026-11-04). Data ricerca: 2026-11-04. Contesto: Flutter 3.47.8 (`.fvmrc`), target macOS 12.0, app macOS **in sandbox** (`macos/Runner/Release.entitlements`), artefatti e appcast su Cloudflare R2, solo macOS per ora (Windows rimandato). Sblocca #122.

**Decisione dell'autore (annotata su #118): Sparkle nativo.**

Legenda: **[F]** fatto osservato in fonte primaria, **[I]** inferenza, **[R]** raccomandazione.

## Domanda

Per gli aggiornamenti macOS conviene adottare il plugin `auto_updater` (leanflutter) o integrare Sparkle 2 direttamente in `macos/Runner`, sul modello di `LaunchAtLogin.swift` (#38)? La scelta resta compatibile con WinSparkle quando si riprenderà Windows?

## Risposta breve

- **`auto_updater` supera il controllo di autenticità ma non quello di manutenzione**: ultimo rilascio 1.0.0 del 27/10/2024, nessun codice dopo quella data, 30 issue aperte e PR di SwiftPM ferma.
- **Il blocco concreto è CocoaPods**: il plugin prende Sparkle solo da CocoaPods, che ha Sparkle fermo alla 2.9.6 (upstream è alla 2.10.1). Il registro CocoaPods diventa di sola lettura il 2/12/2026. Con il plugin Sparkle resterebbe congelato.
- **Lato Windows il plugin include WinSparkle 0.8.1 (solo DSA)**, mentre WinSparkle è alla 0.9.4, con EdDSA e DSA deprecato. Il vantaggio del «un plugin per due piattaforme» è quindi già scaduto.
- **Sparkle nativo costa poco**: un pacchetto SwiftPM nel Runner, quattro chiavi in `Info.plist`, due eccezioni nelle entitlements della sandbox, un file Swift di circa 40 righe e una voce di menu. Stima: 0,5–1 giorno, più la pipeline di firma dell'appcast (necessaria con entrambe le opzioni).
- **[R] Sparkle nativo via MethodChannel.** Per Windows, in futuro: WinSparkle 0.9.x nativo nel runner Windows, con lo stesso canale Dart.

## Tabella di confronto

| Criterio | `auto_updater` 1.0.0 | Sparkle nativo (SwiftPM + MethodChannel) |
|---|---|---|
| Autenticità | OK: publisher verificato `leanflutter.dev`, link dal repo upstream | OK: repo `sparkle-project/Sparkle`, SwiftPM documentato upstream |
| Manutenzione | Ferma: ultimo codice 10/2024, issue «is the project dead?» (#83) senza risposta del maintainer | Attiva: 2.10.1 del 25/10/2026, rilasci circa mensili |
| Versione di Sparkle | Non fissata nel podspec; CocoaPods offre al massimo la 2.9.6 | La scegli tu (SPM «up to next major»): 2.10.1 oggi |
| Gestore pacchetti | Solo CocoaPods (PR SwiftPM #86 aperta) | SwiftPM, il default di Flutter dalla 3.44 |
| Conflitti con `pubspec.lock` | Nessuno: nessuna dipendenza da `win32`; `json_annotation` e `path` già presenti | Nessuna dipendenza Dart |
| Firma EdDSA appcast | Sì su macOS (`sign_update` di Sparkle dai Pods); su Windows solo DSA | Sì, con gli strumenti della release di Sparkle |
| Sandbox | Il plugin non configura nulla: le chiavi e le entitlements vanno aggiunte comunque a mano | Stesse chiavi e entitlements, aggiunte a mano |
| Hardened runtime / notarizzazione | Uguale (dipende dal framework Sparkle e dalla firma Developer ID) | Uguale |
| Superficie Dart | API ampia (eventi, `setFeedURL`, intervallo) | 1–2 metodi (`checkForUpdates`, eventualmente `canCheckForUpdates`) |
| Sforzo iniziale | Basso (0,5 giorni), più la configurazione sandbox | 0,5–1 giorno |
| Sforzo di manutenzione | Alto e imprevedibile: fork alla prima rottura di Flutter o Sparkle | Basso: aggiornare la versione SPM |
| Testabilità | Fake del plugin in Dart; nativo non testabile | Fake del canale in Dart (come `LaunchAtLogin`); la parte nativa si verifica in QA |
| Windows futuro | WinSparkle 0.8.1 incluso come DLL precompilata, DSA, bug aperti (#53, #65, #68, #72) | WinSparkle 0.9.x da integrare nel runner Windows: lavoro in più, ma su una versione attuale |

## Evidenze

### `auto_updater`: dependency vetting

- [F] Il repo upstream `github.com/leanflutter/auto_updater` (MIT, non archiviato, 347 stelle) rimanda dal README a `pub.dev/packages/auto_updater`. Su pub.dev i pacchetti `auto_updater`, `auto_updater_macos`, `auto_updater_windows` e `auto_updater_platform_interface` sono del publisher verificato `leanflutter.dev`, con homepage che punta allo stesso repo. **Autenticità: superata.** https://github.com/leanflutter/auto_updater, https://pub.dev/packages/auto_updater
- [F] Tutti e quattro i pacchetti sono alla 1.0.0, pubblicata il 27/10/2024. Dopo quella data sul branch `main` ci sono solo commit di README (marzo 2025). `pushed_at` è il 29/03/2025. API GitHub `repos/leanflutter/auto_updater/commits`, consultata il 2026-11-04.
- [F] Ci sono 30 issue aperte. Tra le più recenti: #83 «is the project dead?» (03/2026), con un solo commento di un utente che suggerisce `desktop_updater`; #79 «Fail to Download New Version On Both MacOS and Windows» (11/2025); #84 sul nome dell'app che non si aggiorna in /Applications. Restano aperte la PR #86 «Add SwiftPM support» (06/2026) e la PR #85. https://github.com/leanflutter/auto_updater/issues
- [F] Dipendenze di `auto_updater` 1.0.0: `auto_updater_macos`, `auto_updater_platform_interface`, `auto_updater_windows` (tutte ^1.0.0), `json_annotation ^4.8.0`, `path ^1.8.3`. Le implementazioni di piattaforma dipendono solo da `flutter` e `plugin_platform_interface`. Ambiente: `sdk >=3.0.0 <4.0.0`, `flutter >=3.3.0`. API pub.dev `api/packages/<nome>`.
- [F] **Nessuna dipendenza da `win32`**. In `pubspec.lock` c'è `win32 6.4.0`, richiesto da `flutter_secure_storage_windows` (`win32: ^6.0.1`). Il conflitto avuto con `launch_at_startup` (win32 5) quindi non si ripete. [I] `json_annotation` e `path` sono già nel lock e i vincoli sono larghi: `pub get` non dovrebbe cambiare versioni.
- [F] Il podspec di `auto_updater_macos` dichiara `s.dependency 'Sparkle'` senza versione e `s.platform = :osx, '10.11'`. Non esiste un `Package.swift`: il plugin si integra solo via CocoaPods. Archivio `auto_updater_macos-1.0.0.tar.gz` da pub.dev.
- [F] Il codice macOS del plugin (134 righe) crea `SPUUpdater` + `SPUStandardUserDriver` a mano, fornisce l'URL del feed dal delegate (`feedURLString(for:)`) e inoltra gli eventi a Dart. Stesso archivio, `Classes/AutoUpdater.swift`.
- [F] Il plugin Windows include una copia precompilata di **WinSparkle 0.8.1** (`WinSparkle.dll`/`.lib` in `windows/WinSparkle-0.8.1/x64/Release`). Lo script `bin/sign_update.dart` firma su Windows con `dsa_priv.pem` e scrive `sparkle:dsaSignature="…" length="0"` (si veda la issue #72). Archivio `auto_updater_windows-1.0.0.tar.gz` e `packages/auto_updater/bin/sign_update.dart` su GitHub.
- [F] Issue #68: il canale `dev.leanflutter.plugins/auto_updater_event` invia messaggi da un thread diverso dal platform thread su Windows («may result in data loss or crashes»), senza fix. https://github.com/leanflutter/auto_updater/issues/68
- **Esito del vetting**: pacchetto autentico, nessun conflitto con il lock, ma **manutenzione assente** e Sparkle bloccato su CocoaPods. [R] Non adottarlo.

### Sparkle 2 e il gestore pacchetti

- [F] Ultime release di Sparkle: 2.10.1 (25/10/2026), 2.10.0 (13/09/2026), 2.9.6 (17/08/2026). https://github.com/sparkle-project/Sparkle/releases
- [F] Su CocoaPods trunk l'ultimo pod `Sparkle` è la **2.9.6**: la 2.10.x non è stata pubblicata. API `trunk.cocoapods.org/api/v1/pods/Sparkle`, consultata il 2026-11-04.
- [F] Dalla 3.44 Flutter abilita SwiftPM di default. CocoaPods è in manutenzione e il suo registro diventa di sola lettura il 2/12/2026. I due sistemi convivono: Flutter usa CocoaPods per i plugin che non supportano SwiftPM. Pagina aggiornata il 31/08/2026 per Flutter 3.47. https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers
- [I] Con `auto_updater`, Sparkle resterebbe alla 2.9.6 per sempre, salvo un fork del plugin. Il progetto oggi ha ancora un `Podfile` (9 pod nel `Podfile.lock`, nessun pacchetto SwiftPM nel `project.pbxproj`). Aggiungere Sparkle via SPM al target Runner non richiede di togliere CocoaPods.
- [F] La documentazione Sparkle indica SwiftPM (File › Add Packages, `https://github.com/sparkle-project/Sparkle`) e Carthage come installazioni di base. CocoaPods compare solo per le pre-release. https://sparkle-project.org/documentation/

### Setup di Sparkle, firma EdDSA, notarizzazione

- [F] Setup di base: un oggetto `SPUStandardUpdaterController` (in `MainMenu.xib` o creato in codice), una voce «Check for Updates…» con azione `checkForUpdates:`, e in `Info.plist` `SUFeedURL` (URL dell'appcast) e `SUPublicEDKey` (chiave pubblica EdDSA in base64). `CFBundleVersion` deve crescere a ogni versione. Il controllo automatico non richiede altre chiamate API. https://sparkle-project.org/documentation/
- [F] `generate_keys` salva la chiave privata EdDSA nel portachiavi di login e stampa quella pubblica; `-x`/`-f` la esportano e la importano (servono per la CI sul runner self-hosted). `generate_appcast` crea appcast, firme e delta da una cartella di archivi; `sign_update` restituisce `sparkle:edSignature` e `length` per l'`<enclosure>`. Con `SURequireSignedFeed` si firmano anche l'appcast e le note di rilascio. https://sparkle-project.org/documentation/ e https://sparkle-project.org/documentation/publishing/
- [F] `SURequireSignedFeed` (da Sparkle 2.9) fa validare la firma di appcast e note di rilascio, e richiede come prerequisito `SUVerifyUpdateBeforeExtraction = YES` (da 2.7.3), che verifica l'aggiornamento prima di estrarlo. https://sparkle-project.org/documentation/customization/#security-settings
- [F] La Library Validation fa parte dell'hardened runtime ed è necessaria per la notarizzazione. Con una firma ad-hoc Sparkle può non caricarsi; la firma Developer ID evita il problema. In Debug serve un certificato «Apple Development» oppure la Library Validation disattivata. https://sparkle-project.org/documentation/
- [F] Sparkle distribuisce i servizi XPC e gli helper già firmati ad-hoc con hardened runtime. Esportando da Xcode la firma è automatica. Firmando a mano si rifirma ogni componente con `-o runtime`, senza `--deep`. https://sparkle-project.org/documentation/sandboxing/
- [I] La notarizzazione vale allo stesso modo per entrambe le opzioni: dipende dal framework Sparkle incluso e dalla pipeline di #119, non dal plugin.

### Sandbox (Postino è sandboxed)

- [F] Un'app in sandbox deve impostare `SUEnableInstallerLauncherService = YES` in `Info.plist` e aggiungere l'entitlement `com.apple.security.temporary-exception.mach-lookup.global-name` con `$(PRODUCT_BUNDLE_IDENTIFIER)-spks` e `$(PRODUCT_BUNDLE_IDENTIFIER)-spki`. Con `com.apple.security.network.client` (già presente in Postino) non serve `SUEnableDownloaderService`. https://sparkle-project.org/documentation/sandboxing/
- [I] `auto_updater` non aggiunge nessuna di queste chiavi: la configurazione della sandbox è lavoro manuale con entrambe le opzioni. È il passo più delicato, e il plugin non lo semplifica.
- [I] L'entitlement «temporary-exception» è accettato per Developer ID. Per un eventuale App Store/TestFlight Mac servirebbe un'altra strada (lì Sparkle non si usa). Non riguarda le decisioni attuali.

### Come sarebbe l'integrazione nativa

Sul modello di `macos/Runner/LaunchAtLogin.swift`, registrato in `MainFlutterWindow.swift`:

1. **Dipendenza**: pacchetto SwiftPM `https://github.com/sparkle-project/Sparkle`, «Up to Next Major» da 2.10.1, collegato al target Runner (modifica a `project.pbxproj`).
2. **`Info.plist`**: `SUFeedURL` (URL R2 dell'appcast), `SUPublicEDKey`, `SUEnableInstallerLauncherService = YES`, `SUVerifyUpdateBeforeExtraction = YES`, `SURequireSignedFeed = YES`, e facoltativo `SUEnableAutomaticChecks`.
3. **Entitlements** (`Release.entitlements` e `DebugProfile.entitlements`): le due eccezioni mach-lookup `-spks`/`-spki`.
4. **`macos/Runner/Updater.swift`** (circa 40 righe): un `SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)` tenuto per tutta l'esecuzione, e un canale `it.postino/updater` con `checkForUpdates` (e `canCheckForUpdates` se si vuole disabilitare la voce durante un controllo).
5. **Menu «Cerca aggiornamenti…»**: nel menu dell'app in `MainMenu.xib`, collegato direttamente a `checkForUpdates:`, senza passare da Dart. Nel menu della tray (`lib/core/data/desktop/native_system_tray.dart`, `tray_manager`) serve invece la chiamata al canale.
6. **Dart**: una porta/adattatore minimo in `core/data/desktop` con un fake per i test, come per l'avvio al login.

- [I] Stima: 0,5–1 giorno per i punti 1–6, QA esclusa. A parte, e necessari con entrambe le opzioni: generazione delle chiavi, `generate_appcast` in CI e upload su R2 (#119/#122).
- [I] Testabilità: come `LaunchAtLogin`. Il lato Dart si testa con un fake del canale; l'aggiornamento reale si verifica in QA installando una build vecchia e pubblicando un appcast con una build nuova. Una UI Sparkle fornita da Sparkle stesso riduce la superficie da testare.

### Windows (WinSparkle), solo per compatibilità

- [F] WinSparkle 0.9.0 (27/03/2025) ha aggiunto le firme **EdDSA (Ed25519)** e `winsparkle-tool`; il DSA è deprecato («will be removed in a future release»). 0.9.1 ha aggiunto la validazione di `win_sparkle_set_eddsa_public_key()`. Ultima release 0.9.4 (21/07/2026). https://github.com/vslavik/winsparkle/releases
- [I] Con `auto_updater`, su Windows si resterebbe su WinSparkle 0.8.1 con DSA deprecato, salvo un fork per aggiornare la DLL. Quel vantaggio quindi non c'è più.
- [I] Con l'integrazione nativa, Windows significa: WinSparkle 0.9.x nel runner Windows (CMake), un handler C++ dello stesso canale `it.postino/updater` (`win_sparkle_set_appcast_url`, `win_sparkle_set_eddsa_public_key`, `win_sparkle_init`, `win_sparkle_check_update_with_ui`), con la risposta inviata sul platform thread (l'errore della issue #68). Il codice Dart non cambia. Stima 1 giorno quando ci sarà un runner Windows.
- [I] L'appcast può restare uno solo, con item distinti per `sparkle:os`, oppure si usano due appcast su R2. Due file sono più semplici da generare (`generate_appcast` per macOS, `winsparkle-tool` per Windows) e non hanno svantaggi per questo pubblico.

## Raccomandazione [R]

1. **Integrare Sparkle 2 in modo nativo** (SwiftPM, `SPUStandardUpdaterController`, canale `it.postino/updater`), non `auto_updater`. Motivi in ordine di peso: Sparkle bloccato alla 2.9.6 da CocoaPods, plugin senza manutenzione da due anni, nessun vantaggio sulla sandbox, Windows già legato a una WinSparkle obsoleta.
2. Fissare Sparkle «Up to Next Major» dalla 2.10.1 e aggiornarlo come le altre dipendenze.
3. «Cerca aggiornamenti…» nel menu dell'app via `MainMenu.xib`, e nel menu della tray tramite il canale.
4. Attivare `SUVerifyUpdateBeforeExtraction = YES` e `SURequireSignedFeed = YES` (il secondo richiede il primo; appcast e note firmati oltre agli archivi), dato che l'hosting R2 è esterno al repo.
5. Per Windows, quando arriverà il runner: WinSparkle 0.9.x nativo con EdDSA, dietro lo stesso canale.

## Punti aperti

- Dove si conserva la chiave privata EdDSA: portachiavi del runner self-hosted (`generate_keys -f`) o secret GitHub importato a ogni job? Perderla impedisce gli aggiornamenti futuri.
- `SURequireSignedFeed`: verificare con la versione 2.10.x che `generate_appcast` firmi appcast e note senza passaggi in più nella CI.
- La configurazione della sandbox (eccezioni mach-lookup) va verificata in QA su una build Developer ID notarizzata: il debug da Xcode dei servizi XPC può fallire (documentazione sandboxing).
- Voce di menu nella tray o solo nel menu dell'app: decisione di prodotto per #122.
- Non verificato: se la stessa coppia di chiavi Ed25519 è riusabile tra Sparkle e `winsparkle-tool`. Non incide sulla scelta: si possono usare chiavi separate.
