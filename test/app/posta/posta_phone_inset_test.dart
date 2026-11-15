// On a phone with a notch and a home bar (top and bottom insets) the list starts right under the bars: the bar takes
// the top inset itself, so the rows must not take it a second time.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

/// The distance from the sync status to the first row, on a 400 x 800 phone with the given insets.
Future<double> _gap(WidgetTester tester, {required double top, required double bottom}) async {
  tester.view
    ..physicalSize = const Size(400, 800)
    ..devicePixelRatio = 1
    ..padding = FakeViewPadding(top: top, bottom: bottom)
    ..viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  final p = await h.addAccount('a1');
  for (var i = 1; i <= 8; i++) {
    p.deliver(msg('m$i', subject: 'Fattura $i', date: DateTime.utc(2026, 10, 1, 9, i), conversationId: 't$i'));
  }
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  // Routefly keeps the last navigation in statics.
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  final status = find.byType(PostinoSyncStatus);
  expect(status, findsOneWidget);
  return tester.getTopLeft(find.byType(PostinoMessageTile).first).dy - tester.getBottomLeft(status).dy;
}

void main() {
  testWidgets('the first row starts as far under the sync status with a notch and a home bar as without', (
    tester,
  ) async {
    final flat = await _gap(tester, top: 0, bottom: 0);
    final phone = await _gap(tester, top: 47, bottom: 34);
    expect(phone, flat);
  });
}
