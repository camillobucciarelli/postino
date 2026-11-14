// A new version of Postino (#287): the daily check at start and back in foreground, and the Banner on top of the
// Posta, with a fake updater.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/harness.dart';

final _banner = find.byKey(const ValueKey('update-banner'));
final _update = (version: '1.3.0', url: Uri.parse('https://example.org/Postino.apk'));

Future<Harness> _start(WidgetTester tester, {double textScale = 1}) async {
  tester.view
    ..physicalSize = const Size(400, 800)
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final h = await Harness.create();
  h.updater.supported = true;
  await h.addAccount('a1');
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('the app asks for the daily check at start and each time it comes back', (tester) async {
    final h = await _start(tester);
    expect(h.updater.dailyChecks, 1);
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(h.updater.dailyChecks, 2);
  });

  testWidgets('nothing on top of the Posta while there is no new version', (tester) async {
    await _start(tester);
    expect(_banner, findsNothing);
  });

  testWidgets('a new version shows on the Posta: «Aggiorna» downloads it, «Chiudi» hides it', (tester) async {
    final h = await _start(tester);
    h.updater.offer(_update);
    await tester.pumpAndSettle();
    expect(find.text('È disponibile Postino 1.3.0'), findsOneWidget);

    await tester.tap(find.text('Aggiorna'));
    await tester.pumpAndSettle();
    expect(h.updater.downloads, 1);

    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();
    expect(_banner, findsNothing);
  });

  testWidgets('read by the screen reader, its buttons reached and pressed from the keyboard', (tester) async {
    final semantics = tester.ensureSemantics();
    final h = await _start(tester);
    h.updater.offer(_update);
    await tester.pumpAndSettle();
    expect(find.semantics.byPredicate((n) => n.label.contains('È disponibile Postino 1.3.0')), findsAtLeast(1));
    for (final label in ['Aggiorna', 'Chiudi']) {
      expect(
        tester.getSemantics(find.ancestor(of: find.text(label), matching: find.byType(Semantics)).first),
        isSemantics(label: label, isButton: true, isFocusable: true),
      );
    }
    Focus.of(tester.element(find.text('Chiudi'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_banner, findsNothing);
    semantics.dispose();
  });

  testWidgets('at 200% text the Banner fits, buttons under the text', (tester) async {
    final h = await _start(tester, textScale: 2);
    h.updater.offer(_update);
    await tester.pumpAndSettle();
    expect(_banner, findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('Aggiorna')).dy,
      greaterThan(tester.getBottomLeft(find.text('È disponibile Postino 1.3.0')).dy),
    );
  });
}
