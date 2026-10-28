import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:routefly/routefly.dart';

import 'core/data/sync_engine.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(environment: Environment.prod);
  LocaleSettings.useDeviceLocaleSync();
  runApp(TranslationProvider(child: const PostinoApp()));
}

@Main('lib/app')
class PostinoApp extends StatefulWidget {
  const PostinoApp({super.key});

  @override
  State<PostinoApp> createState() => _PostinoAppState();
}

class _PostinoAppState extends State<PostinoApp> {
  @override
  void initState() {
    super.initState();
    unawaited(getIt<SyncEngine>().syncAll());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: Routefly.routerConfig(
        routes: routes,
        initialPath: routePaths.posta,
      ),
      theme: PostinoTheme.light(),
      darkTheme: PostinoTheme.dark(),
      onGenerateTitle: (context) => context.t.appTitle,
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
