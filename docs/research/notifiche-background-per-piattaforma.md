# Notifiche e lavoro in background per piattaforma

Ticket: #4 (mappa #1). Data della ricerca: 2026-10-28. Flutter 3.47.8.

## Domanda

Su iOS, Android, macOS, Windows e Linux, cosa permette Flutter per notifiche locali, lavoro in background e azioni dalla notifica, senza backend (ADR 0001)? Quali limiti di frequenza e quali plugin mantenuti?

## Risposta breve

- **Notifiche locali e Azioni**: `flutter_local_notifications` copre tutte e cinque le piattaforme, e tutte accettano almeno due pulsanti, quindi il limite di due Azioni del glossario sta ovunque. Cosa cambia da una piattaforma all'altra è **dove gira l'Azione**. Su iOS e Android gira in un isolate in background, senza aprire l'app. Su macOS e Linux gira solo nell'isolate principale, cioè ad app avviata. Su Windows (app non UWP) un pulsante avvia sempre l'app in primo piano.
- **Background su mobile**: non c'è modo di tenere aperto IMAP IDLE in background su iOS. Restano i `BGAppRefreshTask`: fino a 30 s, quando lo decide il sistema, mai dopo un force-quit. Su Android si può, con un foreground service con notifica persistente. Però il tipo `dataSync` è limitato a 6 ore ogni 24 (Android 15+), quindi per IDLE continuo serve `specialUse`. In alternativa c'è WorkManager periodico, minimo 15 minuti.
- **Desktop**: nessun limite di sistema rilevante. Bastano tray (`tray_manager`) e avvio al login (`launch_at_startup`), più su macOS un'asserzione `NSProcessInfo` contro App Nap.

## Fatti osservati (con fonte)

### Plugin

| Plugin | Versione (pub.dev, 2026-10-28) | Publisher | Piattaforme | Note |
|---|---|---|---|---|
| `flutter_local_notifications` | 22.3.3 (pubblicata 3 giorni fa) | dexterx.dev (verificato) | Android, iOS, macOS, Linux, Windows, Web | [pub.dev](https://pub.dev/packages/flutter_local_notifications) |
| `flutter_local_notifications_windows` | 3.1.1 (4 mesi fa) | idem | Windows | Senza package identity (MSIX), `cancel` non fa nulla e `getActiveNotifications` restituisce una lista vuota. Niente notifiche periodiche. Richiede `appName`, `appUserModelId`, `guid` ([pub.dev](https://pub.dev/packages/flutter_local_notifications_windows), [sorgente](https://github.com/MaikuB/flutter_local_notifications/blob/master/flutter_local_notifications_windows/lib/src/details/initialization_settings.dart)) |
| `workmanager` | 0.10.10 (50 giorni fa) | fluttercommunity.dev (verificato) | Android, iOS, macOS (Linux/Web sperimentali) | Su iOS usa BGTaskScheduler. Su macOS usa NSBackgroundActivityScheduler, che gira solo ad app aperta o in background, "not after quit" ([pub.dev](https://pub.dev/packages/workmanager)) |
| `flutter_foreground_task` | 11.0.3 (51 giorni fa) | pravera.me (verificato) | Android, iOS | Su Android serve un foreground service tipizzato. Su iOS il task gira "circa 30 secondi ogni 15 minuti" e si ferma col force-quit ([pub.dev](https://pub.dev/packages/flutter_foreground_task)) |
| `tray_manager` | 0.8.0 (19 giorni fa) | leanflutter.dev (verificato) | macOS, Windows, Linux | Richiede Flutter 3.47. Su Linux usa StatusNotifierItem via D-Bus. Su GNOME l'icona compare solo con l'estensione AppIndicator (attiva di default su Ubuntu). Su Linux non arrivano eventi di clic ([pub.dev](https://pub.dev/packages/tray_manager)) |
| `launch_at_startup` | 0.5.1 (19 mesi fa) | leanflutter.dev (verificato) | macOS, Windows, Linux | Ultimo rilascio datato. Su macOS usa il pacchetto LaunchAtLogin ([pub.dev](https://pub.dev/packages/launch_at_startup)) |

### Azioni dalla notifica

| Piattaforma | Pulsanti max | Dove gira l'Azione (con `flutter_local_notifications`) | Fonte |
|---|---|---|---|
| Android | 3 | Isolate in background (`onDidReceiveBackgroundNotificationResponse`) se `showsUserInterface` è falso | [Android: build notification](https://developer.android.com/develop/ui/views/notifications/build-notification), [README plugin](https://github.com/MaikuB/flutter_local_notifications/blob/master/flutter_local_notifications/README.md) |
| iOS | Il limite non è documentato nella pagina Apple consultata | Il sistema "launches your app in the background". Il plugin avvia un engine Flutter separato, che richiede `setPluginRegistrantCallback` in AppDelegate. A dispositivo bloccato i file con protezione *complete* possono non essere accessibili | [Apple: actionable notifications](https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types), README plugin |
| macOS | Come iOS (categorie) | Solo nell'isolate principale (`onDidReceiveNotificationResponse`), quindi serve l'app avviata | README plugin |
| Windows | 5, voci del menu contestuale comprese | Per le app Windows App SDK / non UWP "the app is always launched in the foreground". L'app gestisce l'Azione e può chiudersi | [MS Learn: notification content](https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/app-notifications-content) |
| Linux | Dipende dal server di notifica (capability `actions`, che il server "is free to ignore") | Solo nell'isolate principale. Ad app chiusa non arriva nulla senza attivazione D-Bus, che il plugin non implementa | [freedesktop spec](https://specifications.freedesktop.org/notification/latest/protocol.html), README plugin |

Android 13+ richiede il permesso runtime `POST_NOTIFICATIONS` ([fonte](https://developer.android.com/develop/ui/views/notifications/build-notification)).

### Lavoro in background e limiti di frequenza

| Piattaforma | Meccanismo | Limite | Fonte |
|---|---|---|---|
| iOS | `BGAppRefreshTask` (`workmanager` periodic / background fetch) | Fino a 30 s e "the system decides the best time". Nessuna frequenza garantita: `earliestBeginDate` è solo un minimo, e `workmanager` indica 15 min come minimo e il fetch "typically once per day" | [Apple: choosing background strategies](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app), [workmanager docs](https://docs.page/fluttercommunity/flutter_workmanager/quickstart) |
| iOS | Connessione persistente (IDLE) | Non esiste un meccanismo documentato. Resta solo `beginBackgroundTask`, cioè un breve tempo per finire un lavoro in corso | Apple, stessa pagina |
| iOS | Background push (`content-available`) | Più di 3 all'ora vengono limitate, e servirebbe un server APNs, escluso dall'ADR 0001 | Apple, stessa pagina |
| Android | WorkManager periodico | Minimo 15 min. L'orario è solo indicativo, e i run possono slittare o saltare | [Android: define work](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work) |
| Android | Foreground service `dataSync` | 6 h ogni 24 h in background (target Android 15+), poi `onTimeout` e stop. Non avviabile da `BOOT_COMPLETED` | [FGS timeout](https://developer.android.com/develop/background-work/services/fgs/timeout), [FGS types](https://developer.android.com/develop/background-work/services/fgs/service-types) |
| Android | Foreground service `specialUse` | Nessun timeout documentato. Va dichiarato nel manifest con la motivazione, e la revisione avviene solo su Google Play | FGS types |
| Android | Doze | Rete sospesa fuori dalle finestre di manutenzione. Le app esenti dall'ottimizzazione batteria "can use the network" in Doze. Disattivare l'ottimizzazione permette anche di avviare un FGS dal background | [Doze](https://developer.android.com/training/monitoring-device-state/doze-standby), [FGS da background](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) |
| macOS | Processo in barra dei menu | Nessun limite di sistema, ma App Nap rallenta timer e I/O delle app non in primo piano. Un'asserzione `NSProcessInfo` lo evita | [Apple: App Nap](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/AppNap.html) |
| Windows / Linux | Processo in tray | Nessun limite documentato per un processo desktop | n/d |

## Inferenze

- **iOS**: la notifica di posta nuova arriva solo quando iOS concede un refresh. In 30 s bisogna sincronizzare N Account (incremental history / delta / CONDSTORE, ADR 0008) e mostrare la notifica. Con molti Account il budget può non bastare: conviene limitarsi a "nuovi messaggi in INBOX". Dopo un force-quit non arriva nulla (risposta di Apple DTS sui [forum](https://developer.apple.com/forums/thread/808188), non documentazione ufficiale). Questo conferma la conseguenza già scritta nell'ADR 0001. Correzione all'ADR: "almeno 15 minuti" non è un limite garantito da Apple, che non documenta nessuna frequenza.
- **Android**: per avere "IDLE anche in background" serve un FGS con notifica persistente. Con `dataSync` dopo 6 h si ferma, quindi l'unico tipo adatto all'uso continuo è `specialUse`. Postino non va sugli store (ADR 0001), quindi la revisione Play non è un ostacolo, e neanche la policy Play sull'esenzione dalla batteria. Sui dispositivi di alcuni produttori il processo può comunque essere ucciso: lo dice l'esperienza comune, non una fonte primaria verificata qui.
- **Azioni dalla notifica senza UI**: funzionano su iOS e Android, ma in un isolate separato. Quell'isolate deve aprire da solo il DB SQLCipher (chiave nel keychain, ADR 0003) e mettere l'intento nella coda offline (ADR 0008). Su iOS a dispositivo bloccato la chiave nel keychain deve avere un'accessibilità compatibile, ad esempio *after first unlock*.
- **Desktop**: l'app resta in tray con IDLE attivo (ADR 0001/0008), quindi le notifiche sono "in tempo reale". Le Azioni passano dall'isolate principale, che è già in esecuzione. Su Windows il clic su un pulsante riattiva l'istanza esistente.

## Raccomandazione

1. **Notifiche e Azioni**: `flutter_local_notifications` (con `_windows`) su tutte le piattaforme, con due Azioni al massimo (stanno nei limiti di tutte). Su iOS e Android le Azioni vanno senza UI (isolate in background), e il loro handler scrive solo un intento nella coda locale.
2. **iOS**: `workmanager` con task periodico (BGAppRefresh), trattato come "best effort". Nessuna promessa di tempi nella UI.
3. **Android**: per default WorkManager periodico (15 min). In più un'opzione "notifiche immediate" che avvia un foreground service `specialUse` con IDLE e notifica persistente, e chiede di disattivare l'ottimizzazione batteria. Come plugin, `flutter_foreground_task` oppure un service nativo.
4. **Desktop**: `tray_manager` + `launch_at_startup` (il secondo da vagliare, vedi sotto). Su macOS va tenuta un'asserzione `beginActivity` mentre IDLE è attivo.
5. Aggiornare l'ADR 0001 sulla frequenza iOS: non è "almeno 15 min" ma "a discrezione del sistema".

## Punti aperti

- Quanti pulsanti mostra iOS per categoria nelle versioni attuali. Non trovato nella documentazione consultata, e non è critico con 2 Azioni.
- Se `launch_at_startup` (ultimo rilascio 19 mesi fa) va bene su macOS 13+ (SMAppService) e su Linux. Da vagliare con `supermatt:dependency-vetting`, o da sostituire con poco codice nativo.
- Su Windows non impacchettato (niente MSIX): verificare che il clic su un'Azione ad app chiusa la avvii davvero, tramite AUMID/GUID. Su Linux le Azioni ad app chiusa non arrivano: accettabile, visto che l'app vive in tray?
- Accessibilità del keychain e del DB cifrato da un isolate in background a dispositivo bloccato (iOS).
- Comportamento reale del FGS `specialUse` e dell'esenzione batteria sui dispositivi dei tester (killer dei produttori).
- Il budget di 30 s su iOS basta per N Account? Va misurato con un prototipo.
