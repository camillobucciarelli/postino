import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:routefly/routefly.dart';

import 'i18n/strings.g.dart';
import 'main.config.dart';
import 'main.route.dart';

part 'main.g.dart';

final getIt = GetIt.instance;

@InjectableInit()
void configureDependencies() => getIt.init();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  LocaleSettings.useDeviceLocaleSync();
  runApp(TranslationProvider(child: const PostinoApp()));
}

@Main('lib/app')
class PostinoApp extends StatelessWidget {
  const PostinoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: Routefly.routerConfig(
        routes: routes,
        initialPath: routePaths.posta,
      ),
      onGenerateTitle: (context) => context.t.appTitle,
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
