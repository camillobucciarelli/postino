---
status: Accettato
date: 2026-11-16
---

# Variante Google Play: i flavor Android `site` e `store`

Decisione del titolare del 16/11/2026 (#345): Postino esce anche su Google Play, accanto all'APK del sito (#121), che resta com'è. Su Play l'aggiornamento lo fa Play, e il dialogo di sistema a un tocco per l'esclusione dall'ottimizzazione batteria (Notifiche immediate, #214) non c'è: il suo permesso è materia di policy.

## Decisione

In `android/app/build.gradle.kts` c'è la dimensione `distribution` con due product flavor, **`site`** e **`store`**, entrambi con l'applicationId `com.cbucciarelli.postino`. È lo stesso meccanismo del Mac (ADR 0021): `--flavor store` imposta `appFlavor`.

- **Ogni build Android nomina il flavor.** Con dei product flavor `flutter build apk` senza `--flavor` non sa quale APK cercare, quindi l'APK del sito si costruisce con `--flavor site` e finisce in `build/app/outputs/flutter-apk/app-site-release.apk`. `release.yml` (job `android`) e `ci.yml` (job `android`) sono aggiornati; il nome pubblicato su R2 resta `Postino-<versione>.apk`, la firma resta la chiave di upload, versionCode e versionName quelli di `build_number.sh`. Il flavor `site` non ha sorgenti né manifest propri: è il build di prima con un altro nome.
- **Dart**: con il flavor `store` `appUpdaterFor` dà l'updater non supportato anche su Android, come sul Mac App Store: niente avviso di aggiornamento né link all'APK del sito. `ChannelImmediateNotifications.exemptionInSettings` è vero con `appFlavor == 'store'` e la riga «Notifiche immediate» delle Impostazioni del dispositivo cambia descrizione (`immediateNotificationsBodySettings`): Postino apre le impostazioni dell'ottimizzazione batteria, dove l'utente sceglie di non ottimizzarlo. Etichetta semantica (titolo e descrizione) e navigazione da tastiera (ADR 0014) restano quelle dell'interruttore, coperte da `test/features/impostazioni/immediate_notifications_test.dart` per entrambe le varianti.
- **Manifest**: `android/app/src/store/AndroidManifest.xml` toglie `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` dal manifest unito con `tools:node="remove"`. `tool/release/battery_permission_check.sh` lo controlla sull'APK (`aapt2 dump permissions`): il job `android` di `ci.yml` costruisce entrambi i flavor in debug e verifica che il sito lo dichiari e lo store no; `release.yml` lo verifica sull'APK del sito.
- **Kotlin**: `BatteryExemption.request` apre il dialogo `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` se l'app ha il permesso, altrimenti la schermata `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS` (e, se il dispositivo non ce l'ha, la pagina di Postino nelle impostazioni). Il permesso è di livello normale, quindi è concesso esattamente quando il manifest unito lo dichiara: l'intent lo sceglie il manifest, cioè ciò che Play esamina. Il testo della riga lo sceglie Dart con `isStoreFlavor(appFlavor)` (`lib/core/data/store_flavor.dart`, lo stesso predicato dell'updater), perché serve in modo sincrono al build del widget; che flavor e manifest coincidano lo garantisce `battery_permission_check.sh` in CI.
- **Firma**: senza `ANDROID_KEYSTORE_PATH` un release `site` resta firmato con le chiavi debug (per `flutter run --release --flavor site`); un release `store` fallisce al task `preStoreReleaseBuild`, prima di compilare, invece di firmare con le chiavi debug. Il job `android` di `ci.yml` lo verifica dal messaggio d'errore.

## Verificato sulle fonti Google (16/11/2026)

- [Doze e App Standby, «Support for other use cases»](https://developer.android.com/training/monitoring-device-state/doze-standby#support_for_other_use_cases): la maggior parte delle app può usare l'intent `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`; solo quelle con un caso d'uso accettabile `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. La nota dice che le policy di Google Play vietano di chiedere l'esenzione diretta salvo che la funzione principale dell'app ne sia compromessa. Nella [tabella dei casi accettabili](https://developer.android.com/training/monitoring-device-state/doze-standby#exemption-cases) un'app di messaggistica che non può usare FCM per una dipendenza da un altro servizio è «Acceptable»: Postino potrebbe rientrarci, ma la decisione del titolare è non affidarsi alla revisione.
- [`Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`](https://developer.android.com/reference/android/provider/Settings#ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS) (API 23): nessun input, nessun permesso richiesto. `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` invece richiede il permesso `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` e il package nell'URI.
- [Device and Network Abuse](https://support.google.com/googleplay/android-developer/answer/9888379), la policy di Play: non nomina il permesso, ma vieta di aggirare la gestione dell'energia di sistema alle app non idonee all'allowlist.

## Alternative scartate

- **Un solo flavor `store`** lasciando l'APK del sito senza flavor: Gradle definisce allora solo varianti `store`, e il build senza `--flavor` non produce più `app-release.apk`.
- **Flavor definiti solo quando il task Gradle li nomina** (`gradle.startParameter.taskNames`), per lasciare invariati i comandi: un trucco che Android Studio e la sincronizzazione di Gradle non vedono.
- **`BuildConfig.FLAVOR` in Kotlin** per scegliere l'intent: il dialogo senza il permesso fallirebbe; il permesso dice già quale intent l'app può usare.
- **Chiedere al canale se c'è il permesso** per scegliere il testo: una chiamata asincrona in più a ogni build della riga, per un'informazione che il flavor dà già e che la CI tiene allineata al manifest.
- **`default-flavor` nel `pubspec.yaml`**: vale per tutte le piattaforme, e su macOS e iOS richiederebbe uno schema `site`.

## Conseguenze

- `flutter run` su Android vuole `--flavor site` (o `store`); macOS, iOS e gli altri desktop non cambiano.
- Il job `android` di `ci.yml` costruisce due APK debug invece di uno.
- Il build dell'AAB e l'upload su Play sono la fetta 2 di #345; scheda e dichiarazioni della Play Console la fetta 3.
- Su alcuni dispositivi la schermata di sistema mostra di default solo le app non ottimizzate: l'utente deve scegliere «Tutte le app» per trovare Postino. Il testo della riga non lo dice perché varia per produttore; si verifica con TalkBack sulla prima build della variante.
