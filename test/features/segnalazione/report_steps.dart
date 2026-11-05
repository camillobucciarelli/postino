// Steps of the Segnalazione di un problema tests (#117).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _desktop = Size(1600, 900);

late Harness h;
late FakeMailProvider gmail;

/// The app, Italian, with the log holding "boom"; [crash] leaves the crash mark of the run before.
Future<void> start(WidgetTester tester, {bool account = true, bool crash = false}) async {
  tester.view
    ..physicalSize = _desktop
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  if (account) gmail = await h.addAccount('a1');
  h.errorLog.record('boom', context: 'prova', crash: crash);
  await tester.runAsync(pumpEventQueue);
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

Future<void> fromSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('drawer-impostazioni')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('settings-report-problem')));
  await tester.pumpAndSettle();
  await tester.runAsync(pumpEventQueue);
  await tester.pumpAndSettle();
}

/// Ends the test with the app gone, the composer too: its dispose syncs the Bozza, which must happen before the
/// next test resets the database.
Future<void> close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(pumpEventQueue);
}

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is PostinoComposerField && w.label == label),
  matching: find.byType(TextField),
);

String fieldText(WidgetTester tester, String label) => tester.widget<TextField>(field(label)).controller!.text;
