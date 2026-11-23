// On a phone with a notch and a home bar (top and bottom insets) the list starts right under the bars: the bar takes
// the top inset itself, so the rows must not take it a second time.
import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
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
    // Read: the list has no sections (#366).
    p.deliver(
      msg('m$i', subject: 'Fattura $i', date: DateTime.utc(2026, 10, 1, 9, i), conversationId: 't$i', isRead: true),
    );
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

  testWidgets('the last row still clears the home bar', (tester) async {
    await _gap(tester, top: 47, bottom: 34);
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final last = find.byKey(const ValueKey('row-a1-m1'));
    expect(tester.getBottomLeft(last).dy, lessThanOrEqualTo(800 - 34));
  });

  testWidgets('a page under the bar of PostinoDetailPage starts right under it too', (tester) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 47, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: PostinoTheme.light(),
        home: PostinoDetailPage(
          title: 'T',
          onBack: () {},
          child: ListView(children: const [Text('prima')]),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('prima')).dy - tester.getBottomLeft(find.byType(PostinoAppBar)).dy,
      lessThan(PostinoSpacing.s4),
    );
  });
}
