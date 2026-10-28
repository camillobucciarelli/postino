// Own file: routefly keeps its router config in statics, so the extra route must be the first config of the isolate.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

Widget _appAt(String initialPath) {
  final child = RouteEntity(
    key: '/posta/figlio',
    uri: Uri.parse('/posta/figlio'),
    parent: routePaths.posta,
    routeBuilder: (ctx, settings) =>
        Routefly.defaultRouteBuilder(ctx, settings, const Text('figlio')),
  );
  return TranslationProvider(
    child: MaterialApp.router(
      routerConfig: Routefly.routerConfig(
        routes: [...routes, child],
        initialPath: initialPath,
      ),
    ),
  );
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.it));

  testWidgets('a child route of /posta renders inside the Posta layout', (
    tester,
  ) async {
    await tester.pumpWidget(_appAt('/posta/figlio'));
    await tester.pumpAndSettle();
    expect(find.text('figlio'), findsOneWidget);
    expect(find.text('Posta in arrivo'), findsNothing);
  });

  testWidgets(
    'navigating from a child route to /posta shows the Posta unificata',
    (tester) async {
      await tester.pumpWidget(_appAt('/posta/figlio'));
      await tester.pumpAndSettle();
      Routefly.navigate(routePaths.posta);
      await tester.pumpAndSettle();
      expect(find.text('Posta in arrivo'), findsOneWidget);
      expect(find.text('figlio'), findsNothing);
    },
  );
}
