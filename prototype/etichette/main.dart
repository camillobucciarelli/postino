// PROTOTIPO usa-e-getta (#106): flussi UI delle Etichette e del download del modello.
// flutter run -t prototype/etichette/main.dart -d macos [--dart-define=VARIANT=b]
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

import 'posta_screen.dart';
import 'proto_bar.dart';
import 'proto_state.dart';

final _light = PostinoTheme.light();
final _dark = PostinoTheme.dark();

void main() {
  const v = String.fromEnvironment('VARIANT', defaultValue: 'a');
  proto
    ..variant = ProtoVariant.values.firstWhere((x) => x.name == v.toLowerCase(), orElse: () => ProtoVariant.a)
    ..onReady = () => ScaffoldMessenger.of(
      appContext,
    ).showSnackBar(SnackBar(content: Semantics(liveRegion: true, child: const Text('Etichette automatiche pronte'))));
  runApp(Proto(notifier: proto, child: const ProtoApp()));
}

class const ProtoApp({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Proto.of(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Postino · prototipo Etichette',
      theme: _light,
      darkTheme: _dark,
      themeMode: s.dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => ProtoShortcuts(
        child: Stack(
          children: [
            MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: s.large ? const TextScaler.linear(2) : MediaQuery.textScalerOf(context)),
              child: Builder(
                builder: (context) {
                  appContext = context;
                  return child!;
                },
              ),
            ),
            const Positioned(
              left: PostinoSpacing.s4,
              right: PostinoSpacing.s4,
              bottom: PostinoSpacing.s4,
              child: Center(child: ProtoBar()),
            ),
          ],
        ),
      ),
      home: const PostaScreen(),
    );
  }
}
