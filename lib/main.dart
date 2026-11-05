import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:routefly/routefly.dart';
import 'package:workmanager/workmanager.dart';

import 'app/posta/posta_routes.dart' show openConversation;
import 'core/data/accounts_settings_mirror.dart';
import 'core/data/background_send.dart';
import 'core/data/error_log/uncaught_errors.dart';
import 'core/data/postino_database.dart';
import 'core/data/settings_sync.dart';
import 'core/data/sync_engine.dart';
import 'core/domain/app_window.dart';
import 'core/domain/error_log.dart';
import 'core/domain/launch_at_login_use_case.dart';
import 'core/domain/mail_notification.dart';
import 'core/domain/notifications.dart';
import 'core/domain/system_tray.dart';
import 'core/presentation/desktop_tray.dart';
import 'design_system/tokens/postino_theme.dart';
import 'i18n/strings.g.dart';
import 'main.config.dart';
import 'main.route.dart';

part 'main.g.dart';

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies({String? environment}) async {
  await getIt.init(environment: environment);
}

/// Android WorkManager entry point (#36): a fresh isolate wires the app's DI and runs [runOutboxTask].
@pragma('vm:entry-point')
void sendOutboxDispatcher() {
  Workmanager().executeTask((task, input) async {
    final accountId = input?['accountId'] as String?;
    if (accountId == null) return true;
    try {
      DartPluginRegistrant.ensureInitialized();
      await configureDependencies(environment: Environment.prod);
    } on Object catch (e) {
      debugPrint('[background] $accountId: setup failed, $e');
      return true;
    }
    return runOutboxTask(accountId);
  });
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
    // The outbox keeps going after the user leaves the app (#36).
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

/// Before `runApp` (#39): the notifications ready, and the Conversazione whose notification launched the app.
/// Failing keeps Postino from notifying, not from running.
Future<ConversationKey?> _startNotifications() async {
  try {
    return await getIt<Notifications>().start(channelName: t.notifiche.channel, openLabel: t.notifiche.open);
  } on Object catch (e) {
    debugPrint('[notifiche] start: $e');
    return null;
  }
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
        await getIt<AccountsSettingsMirror>().stop();
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

  /// The Conversazione whose notification launched the app (cold start): it opens over the Posta unificata.
  final ConversationKey? launch,
}) extends StatefulWidget {
  @override
  State<PostinoApp> createState() => _PostinoAppState();
}

class _PostinoAppState() extends State<PostinoApp> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<ConversationKey>? _taps;

  /// Built once: routefly keeps its router in statics.
  late final RouterConfig<Object> _router = Routefly.routerConfig(routes: routes, initialPath: routePaths.posta.path)!;

  @override
  void initState() {
    super.initState();
    getIt<SyncEngine>().start();
    getIt<SettingsSync>().start();
    getIt<AccountsSettingsMirror>().start();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(getIt<SyncEngine>().syncAll()));
    _whenRouted(() {
      if (widget.launch case final launch?) _open(launch);
      _taps = getIt<Notifications>().taps.listen((key) {
        // On desktop the window may be hidden in the tray.
        if (_desktop) unawaited(getIt<AppWindow>().show().catchError((Object e) => debugPrint('[desktop] window: $e')));
        _open(key);
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

  /// Over the Posta unificata, whichever list was in front: its frame first, so Indietro comes back to it.
  void _open(ConversationKey key) => unawaited(
    Routefly.navigate(routePaths.posta.path)
        .then((_) => WidgetsBinding.instance.endOfFrame)
        .then((_) => openConversation(key.accountId, key.conversationId)),
  );

  @override
  void dispose() {
    unawaited(_taps?.cancel());
    _lifecycle.dispose();
    unawaited(getIt<SyncEngine>().stop());
    unawaited(getIt<SettingsSync>().stop());
    unawaited(getIt<AccountsSettingsMirror>().stop());
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
