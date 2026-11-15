// Impostazioni → «Informativa sulla privacy» (#323, Apple guideline 5.1.1(i)): the site's page in the app's
// language, opened outside Postino; a button for the screen reader, reached with Tab and opened with Enter.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/harness.dart';

final _link = find.byKey(const ValueKey('settings-privacy'));

Future<Harness> _start(WidgetTester tester, AppLocale locale) async {
  tester.view
    ..physicalSize = const Size(1200, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  await h.addAccount('a1');
  LocaleSettings.setLocaleSync(locale);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.impostazioni.path));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  for (final (locale, label, url) in [
    (AppLocale.it, 'Informativa sulla privacy', 'https://postino.camillobucciarelli.dev/privacy.html'),
    (AppLocale.en, 'Privacy policy', 'https://postino.camillobucciarelli.dev/en/privacy.html'),
  ]) {
    testWidgets('${locale.languageCode}: «$label» opens $url', (tester) async {
      final h = await _start(tester, locale);
      await tester.scrollUntilVisible(_link, 100);
      expect(
        tester.getSemantics(_link),
        matchesSemantics(label: label, isButton: true, isFocusable: true, hasTapAction: true, hasFocusAction: true),
      );

      await tester.tap(_link);
      await tester.pumpAndSettle();
      expect(h.links.opened, [Uri.parse(url)]);
    });
  }

  testWidgets('Tab reaches the link and Enter opens it', (tester) async {
    final h = await _start(tester, AppLocale.it);
    await tester.scrollUntilVisible(_link, 100);
    bool focused() => find
        .ancestor(of: find.byElementPredicate((e) => e == FocusManager.instance.primaryFocus?.context), matching: _link)
        .evaluate()
        .isNotEmpty;
    for (var i = 0; i < 60 && !focused(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focused(), isTrue, reason: 'a Tab stop');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(h.links.opened, [Uri.parse('https://postino.camillobucciarelli.dev/privacy.html')]);
  });
}
