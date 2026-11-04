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

import 'core/data/background_send.dart';
import 'core/data/postino_database.dart';
import 'core/data/sync_engine.dart';
import 'core/domain/app_window.dart';
import 'core/domain/launch_at_login_use_case.dart';
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
  runApp(TranslationProvider(child: const PostinoApp()));
  if (!kIsWeb &&
      const {TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux}.contains(defaultTargetPlatform)) {
    unawaited(_startDesktop());
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
        await getIt<PostinoDatabase>().close();
      },
    );
  } on Object catch (e) {
    debugPrint('[desktop] tray: $e');
  }
}

@Main('lib/app')
class const PostinoApp({super.key}) extends StatefulWidget {
  @override
  State<PostinoApp> createState() => _PostinoAppState();
}

class _PostinoAppState() extends State<PostinoApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    getIt<SyncEngine>().start();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(getIt<SyncEngine>().syncAll()));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(getIt<SyncEngine>().stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: Routefly.routerConfig(routes: routes, initialPath: routePaths.posta.path),
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
