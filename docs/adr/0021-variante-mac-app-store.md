---
status: Accettato
date: 2026-11-16
---

# Variante Mac App Store: un target Xcode `Store` senza Sparkle

Decisione del titolare del 15/11/2026 (#325): Postino esce anche sul Mac App Store, accanto al DMG firmato Developer ID con gli aggiornamenti di Sparkle (#122), che resta com'è. Nello Store l'aggiornamento lo fa lo Store: Sparkle non deve esserci, né nel bundle né nei suoi entitlements o nel plist (la revisione Apple rifiuta le eccezioni `mach-lookup` del suo installer).

## Decisione

In `macos/Runner.xcodeproj` c'è un secondo target applicazione, **`Store`**, con lo schema `Store` e la sola configurazione `Release-store`: è la convenzione dei flavor di Flutter, quindi la variante si costruisce con `flutter build macos --release --flavor store` e finisce in `build/macos/Build/Products/Release-store/Postino.app`.

- **Sorgenti**: gli stessi file Swift del Runner tranne `Updater.swift` e `CheckForUpdatesMenuItem.swift`; le due chiamate a Sparkle in `AppDelegate.swift` e `MainFlutterWindow.swift` stanno sotto `#if !APP_STORE` (`SWIFT_ACTIVE_COMPILATION_CONDITIONS = APP_STORE` nel target). Niente dipendenza dal pacchetto Sparkle: il framework non viene né collegato né copiato.
- **Plist ed entitlements propri**: `Runner/Store-Info.plist` è `Info.plist` senza le chiavi `SU*`; `Runner/Store.entitlements` è `Release.entitlements` senza le eccezioni `mach-lookup`. `test/macos/store_variant_test.dart` controlla che restino esattamente così, quindi una chiave aggiunta a uno e dimenticata nell'altro fa fallire i test.
- **In comune con il DMG**: `LSApplicationCategoryType` = `public.app-category.productivity` e `ITSAppUsesNonExemptEncryption` = `false` (esente dal fornire documentazione, ADR 0022) stanno in `Info.plist`, innocui fuori dallo Store; così il plist dello Store resta "quello del DMG meno Sparkle". Il bundle id è lo stesso (`AppInfo.xcconfig`), uguale a quello di iOS per l'acquisto universale.
- **Solo nello Store**: i manifest della privacy. `Runner/PrivacyInfo.xcprivacy` (stesse conclusioni di iOS) e, con la fase "Native assets privacy manifests", quelli dentro `sqlcipher.framework` (lo stesso file di iOS, `ios/sqlcipher/PrivacyInfo.xcprivacy`) e `cnativeapi.framework` (`macos/cnativeapi/PrivacyInfo.xcprivacy`, l'asset nativo del tray, che su macOS usa `NSUserDefaults`). Verificato con `nm -u` sui binari della build.
- **Dart**: `--flavor store` imposta da solo `appFlavor` (`package:flutter/services.dart`); con il flavor `store` `appUpdaterFor` non dà `ChannelAppUpdater` su macOS ma l'updater non supportato: niente banner e niente «Cerca aggiornamenti» nelle Impostazioni. Il confronto ignora maiuscole e minuscole: la build di Xcode passa come flavor il nome dello schema, `Store`. Nessun `--dart-define` da ricordare.
- **Firma e pacchetto** (`release.yml`, job `macos-store`): `sign_app.sh` come per il DMG ma con l'identità Apple Distribution e il profilo Mac App Store, che autorizza lo stesso keychain access group (#270); `.pkg` con `productbuild` firmato Mac Installer Distribution (`keychain_create.sh` esporta il nome completo del certificato, che `productbuild --sign` vuole al posto dell'hash); upload con `testflight_upload.sh <pkg> macos` (`altool -t macos`); controllo con `verify_store.sh` (bundle senza Sparkle con `store_bundle_check.sh`, profilo e entitlements con `profile_check.sh`, firme). Il job parte solo con la variabile del repository `MAC_APP_STORE` = `true`: finché certificati e profilo non esistono è saltato e il DMG non ne dipende.

Il target, lo schema e le configurazioni `Release-store` di Runner e RunnerTests (copie delle `Release`, richieste da `pod install`, che esamina ogni configurazione del progetto) sono le sole aggiunte al progetto. Il target `Runner`, il suo plist e i suoi entitlements restano quelli del DMG.

## Alternative scartate

- **Una sola target con la configurazione `Release-store`** e `EXCLUDED_SOURCE_FILE_NAMES` per i file di Sparkle: Xcode collega e incorpora i prodotti dei pacchetti Swift per target, non per configurazione. Sparkle resterebbe nel bundle e collegato al binario; toglierlo vorrebbe dire `-dead_strip_dylibs` più uno script che cancella il framework prima della firma: due trucchi fragili invece di un target.
- **Post-produzione del bundle del DMG** (cancellare Sparkle e le chiavi `SU*`, rifirmare con altri entitlements): il binario collega Sparkle e non partirebbe senza; con il collegamento debole il codice di Sparkle resterebbe nel binario e servirebbero controlli a runtime.
- **Firma gestita da Xcode con la chiave API** (`xcodebuild archive` + `-exportArchive` per `app-store-connect`, come iOS in `ios_ipa.sh`): niente segreti di certificati, ma l'archivio dovrebbe essere firmato per portarsi dietro gli entitlements del sandbox e il keychain access group, e non si può verificare senza l'account. La strada di `sign_app.sh` è quella già provata con il DMG e controlla esplicitamente profilo ed entitlements.
- **Un `--dart-define` per il lato Dart**: `appFlavor` lo dà già il flavor, senza rischio di dimenticarlo.

## Conseguenze

- Un file Swift nuovo va aggiunto a entrambi i target se lo usano anche i file condivisi: altrimenti la build dello Store non compila. Il job `apple` di `ci.yml` costruisce la variante Store e la passa a `store_bundle_check.sh`, quindi lo si scopre sulla PR e non al rilascio.
- Il DMG cambia solo per le due chiavi comuni del plist; framework, chiavi `SU*` ed entitlements sono identici.
- Stesso bundle id e stesso team: DMG e Store condividono il container del sandbox e il gruppo del Data Protection Keychain, quindi chi passa dal DMG allo Store ritrova i dati.
- Non c'è una configurazione `Debug-store`: la variante Store si prova solo in release (`flutter run --release --flavor store` o il bundle costruito).
- Tray e avvio al login (`SMAppService.mainApp`) nella sandbox dello Store e il keychain con il profilo vero si verificano sulla prima build firmata (#215).
