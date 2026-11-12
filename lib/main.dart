import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show NotificationResponse;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:routefly/routefly.dart';
import 'package:workmanager/workmanager.dart';

import 'app/posta/posta_routes.dart' show openConversation;
import 'core/data/background_send.dart';
import 'core/data/background_sync.dart';
import 'core/data/error_log/uncaught_errors.dart';
import 'core/data/local_notifications.dart' show backgroundActionEntry;
import 'core/data/notification_action_relay.dart';
import 'core/data/notification_payload.dart' show decodeAction;
import 'core/data/platform_services.dart' show SystemPeriodicSync;
import 'core/data/postino_database.dart';
import 'core/data/settings_sync.dart';
import 'core/data/sync/periodic_schedule.dart';
import 'core/data/sync_engine.dart';
import 'core/domain/app_window.dart';
import 'core/domain/error_log.dart';
import 'core/domain/launch_at_login_use_case.dart';
import 'core/domain/notification_action.dart';
import 'core/domain/notification_action_use_case.dart';
import 'core/domain/notification_target.dart';
import 'core/domain/notifications.dart';
import 'core/domain/system_tray.dart';
import 'core/presentation/desktop_tray.dart';
import 'design_system/tokens/postino_theme.dart';
import 'features/impostazioni/presentation/notification_action_label.dart';
import 'i18n/strings.g.dart';
import 'main.config.dart';
import 'main.route.dart';

part 'main.g.dart';

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies({String? environment}) async {
  await getIt.init(environment: environment);
}

/// Android WorkManager entry point: a fresh isolate wires the app's DI, then by the task's name the outbox of an
/// Account (#36, [runOutboxTask]) or the periodic sync (#212, [runSyncTask]), whose notifications it prepares first.
/// Its name stays: WorkManager keeps the callback handle across an update, and a send queued before it still finds it.
@pragma('vm:entry-point')
void sendOutboxDispatcher() {
  Workmanager().executeTask((task, input) async {
    final sync = task == SystemPeriodicSync.task;
    final accountId = input?['accountId'] as String?;
    if (!sync && accountId == null) return true;
    try {
      DartPluginRegistrant.ensureInitialized();
      await configureDependencies(environment: Environment.prod);
    } on Object catch (e) {
      debugPrint('[background] $task: setup failed, ${e.runtimeType}');
      return true;
    }
    if (!sync) return runOutboxTask(accountId!);
    LocaleSettings.useDeviceLocaleSync();
    // Not the app: the buttons tapped meanwhile stay with the app or their own background engine (#211).
    await _startNotifications(app: false);
    return runSyncTask();
  }, onTaskStopped: (task, _) => stopSyncTask());
}

/// A button of a notification tapped outside the app's isolate (#211): iOS and Android run it in a background engine,
/// even while the app is open. The app's isolate takes it when it lives; otherwise this isolate wires the app's DI
/// (once: the engine stays for the next taps) and runs it here, through the offline queue.
@pragma('vm:entry-point')
Future<void> notificationActionDispatcher(NotificationResponse response) async {
  final tap = decodeAction(response.payload, response.actionId);
  if (tap == null) return;
  try {
    if (await relayToApp(tap)) return;
    DartPluginRegistrant.ensureInitialized();
    // Already wired where the DI exists (a test's).
    await (_backgroundDependencies ??= getIt.isRegistered<NotificationActionUseCase>()
        ? Future<void>.value()
        : configureDependencies(environment: Environment.prod));
  } on Object catch (e) {
    // A failed wiring is not kept: the next tap tries again on a clean DI.
    _backgroundDependencies = null;
    await getIt.reset();
    debugPrint('[notifiche] ${tap.conversation.accountId}: background setup failed, ${e.runtimeType}');
    return;
  }
  await _runAction(tap, background: true);
}

/// The DI of the background engine of [notificationActionDispatcher], wired at its first tap.
Future<void>? _backgroundDependencies;

/// [tap]'s Azione; from the [background] engine only the Azioni reach the Provider.
Future<void> _runAction(NotificationActionTap tap, {bool background = false}) async {
  try {
    await getIt<NotificationActionUseCase>().run(tap, background: background);
  } on Object catch (e) {
    // The type only: the error may quote the message.
    debugPrint('[notifiche] ${tap.conversation.accountId}: action failed, ${e.runtimeType}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  captureUncaughtErrors(() => getIt.isRegistered<ErrorLog>() ? getIt<ErrorLog>() : null);
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Caprasimo',
      'Figtree',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    // The outbox keeps going after the user leaves the app (#36), the new mail is checked while it is closed (#212).
    await Workmanager().initialize(sendOutboxDispatcher);
  }
  await configureDependencies(environment: Environment.prod);
  LocaleSettings.useDeviceLocaleSync();
  final launch = await _startNotifications();
  runApp(TranslationProvider(child: PostinoApp(launch: launch)));
  if (_desktop) unawaited(_startDesktop());
}

bool get _desktop =>
    !kIsWeb &&
    const {TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux}.contains(defaultTargetPlatform);

/// Before `runApp` (#39): the notifications ready, and what the notification that launched the app opens.
/// Failing keeps Postino from notifying, not from running. Only the [app]'s isolate takes the notifications' buttons.
Future<NotificationTarget?> _startNotifications({bool app = true}) async {
  backgroundActionEntry = notificationActionDispatcher;
  try {
    return await getIt<Notifications>().start(
      channelName: t.notifiche.channel,
      openLabel: t.notifiche.open,
      newMessages: (n) => t.notifiche.newMessages(n: n),
      actionLabel: (action) => notificationActionLabel(t, action),
      onAction: app ? (tap) => unawaited(_runNotificationAction(tap)) : null,
    );
  } on Object catch (e) {
    debugPrint('[notifiche] start: $e');
    return null;
  }
}

/// A button tapped in the app's isolate (#211). Windows has brought the app forward for it: the window, if hidden in
/// the tray, comes too, then the Azione runs (the limit #28 accepts); macOS and Linux run it from the tray.
Future<void> _runNotificationAction(NotificationActionTap tap) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    await getIt<AppWindow>().show().catchError((Object e) => debugPrint('[desktop] window: $e'));
  }
  await _runAction(tap);
}

/// Desktop (#38): the avvio al login on by default, then the tray. Neither failing keeps Postino from running.
Future<void> _startDesktop() async {
  // A debug run would register the debug build as the login item: there the switch works, the default does not.
  if (!kDebugMode) {
    try {
      await getIt<LaunchAtLoginUseCase>().applyDefault();
    } on Object catch (e) {
      debugPrint('[desktop] avvio al login: $e');
    }
  }
  // The window exists and is shown after the first frame; the AppWindow resolves it then, before the tray exists.
  await WidgetsBinding.instance.endOfFrame;
  try {
    final window = getIt<AppWindow>();
    await DesktopTray(window, getIt<SystemTray>()).start(
      tooltip: t.appTitle,
      openLabel: t.tray.open,
      quitLabel: t.tray.quit,
      beforeQuit: () async {
        await getIt<SyncEngine>().stop();
        await getIt<SettingsSync>().stop();
        await getIt<PostinoDatabase>().close();
      },
    );
  } on Object catch (e) {
    debugPrint('[desktop] tray: $e');
  }
}

@Main('lib/app')
class const PostinoApp({
  super.key,

  /// What the notification that launched the app opens (cold start): a Conversazione over the Posta unificata, or
  /// the inbox of an Account (its summary, #210).
  final NotificationTarget? launch,
}) extends StatefulWidget {
  @override
  State<PostinoApp> createState() => _PostinoAppState();
}

class _PostinoAppState() extends State<PostinoApp> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<NotificationTarget>? _taps;

  /// Built once: routefly keeps its router in statics.
  late final RouterConfig<Object> _router = Routefly.routerConfig(routes: routes, initialPath: routePaths.posta.path)!;

  @override
  void initState() {
    super.initState();
    getIt<SyncEngine>().start();
    getIt<SettingsSync>().start();
    getIt<PeriodicSchedule>().start();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(getIt<SyncEngine>().syncAll()));
    _whenRouted(() {
      if (widget.launch case final launch?) _open(launch);
      _taps = getIt<Notifications>().taps.listen((target) {
        // On desktop the window may be hidden in the tray.
        if (_desktop) unawaited(getIt<AppWindow>().show().catchError((Object e) => debugPrint('[desktop] window: $e')));
        _open(target);
      });
    });
  }

  /// routefly has no initial stack (#8): the app starts on the Posta unificata, and [then] runs after the frame that
  /// drew it, so a Conversazione opened from there comes back to it with Indietro. The taps before are not heard.
  void _whenRouted(VoidCallback then) {
    final delegate = _router.routerDelegate;
    void drawn() => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) then();
    });
    if (delegate.currentConfiguration != null) return drawn();
    void listener() {
      if (delegate.currentConfiguration == null) return;
      delegate.removeListener(listener);
      drawn();
    }

    delegate.addListener(listener);
  }

  /// A Conversazione over the Posta unificata, whichever list was in front: its frame first, so Indietro comes back
  /// to it. An Account's summary opens its inbox, from where Indietro goes to the Posta unificata too (#210).
  void _open(NotificationTarget target) => unawaited(switch (target) {
    ConversationTarget(:final conversation) =>
      Routefly.navigate(routePaths.posta.path)
          .then((_) => WidgetsBinding.instance.endOfFrame)
          .then((_) => openConversation(conversation.accountId, conversation.conversationId)),
    AccountTarget(:final accountId) => Routefly.navigate(
      routePaths.posta.$accountId.path.changes({'accountId': accountId}),
    ),
  });

  @override
  void dispose() {
    unawaited(_taps?.cancel());
    _lifecycle.dispose();
    unawaited(getIt<SyncEngine>().stop());
    unawaited(getIt<SettingsSync>().stop());
    unawaited(getIt<PeriodicSchedule>().stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      theme: PostinoTheme.light(),
      darkTheme: PostinoTheme.dark(),
      onGenerateTitle: (context) => context.t.appTitle,
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      // quill's: without them a tap on a link in the editor throws.
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        ...FlutterQuillLocalizations.localizationsDelegates,
      ],
    );
  }
}
