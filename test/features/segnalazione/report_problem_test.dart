// Segnala un problema (#117): from the drawer and the `p` key, without an Account (the system share sheet), and the
// Dialog offered after a crash.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/app/report_problem.dart';
import 'package:postino/features/segnalazione/domain/problem_report_config.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import 'report_steps.dart';

void main() {
  testWidgets('without an Account, the report from the crash Dialog opens the system share sheet on the log', (
    tester,
  ) async {
    await start(tester, account: false, crash: true);
    await tester.tap(find.text('Segnala'));
    await tester.pumpAndSettle();
    await tester.runAsync(pumpEventQueue);
    expect(h.sharer.shared, hasLength(1));
    final (text, name, subject) = h.sharer.shared.single;
    expect(text, contains('boom'));
    expect(name, problemReportFileName);
    expect(subject, 'Problema in Postino');
  });

  testWidgets('the onboarding has the action too, for who has no Account', (tester) async {
    await start(tester, account: false);
    await tester.tap(find.text('Segnala un problema'));
    await tester.runAsync(pumpEventQueue);
    expect(h.sharer.shared, hasLength(1));
  });

  testWidgets('a key held down starts one report, not one per repeat', (tester) async {
    await start(tester, account: false);
    reportProblem();
    reportProblem();
    await tester.runAsync(pumpEventQueue);
    expect(h.sharer.shared, hasLength(1));
  });

  testWidgets('p during the onboarding shares the log without an Account', (tester) async {
    await start(tester, account: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.runAsync(pumpEventQueue);
    expect(h.sharer.shared, hasLength(1));
  });

  testWidgets('a held p reports once: the repeats after the first report is done start nothing', (tester) async {
    await start(tester, account: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyP);
    await tester.runAsync(pumpEventQueue);
    expect(h.sharer.shared, hasLength(1));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyP);
    await tester.runAsync(pumpEventQueue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyP);
    expect(h.sharer.shared, hasLength(1));
  });

  testWidgets('after a failed report the next one is tried', (tester) async {
    await start(tester, account: false);
    h.sharer.failure = Exception('no sheet');
    reportProblem();
    await tester.pumpAndSettle();
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(h.sharer.shared, isEmpty);

    h.sharer.failure = null;
    reportProblem();
    await tester.pumpAndSettle();
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(h.sharer.shared, hasLength(1));
  });

  testWidgets('the drawer has the action too', (tester) async {
    final semantics = tester.ensureSemantics();
    await start(tester);
    // The screen reader reads the action, and the Dialog of a crash (below) has its own title and buttons.
    expect(find.bySemanticsLabel(RegExp('Segnala un problema')), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('drawer-segnala')));
    await tester.pumpAndSettle();
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(Routefly.currentUri.pathSegments[2], 'bozza');
    await close(tester);
    semantics.dispose();
  });

  testWidgets('the p key starts the report, but not while typing in a text field', (tester) async {
    await start(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(Routefly.currentUri.pathSegments[2], 'bozza');
    final draft = Routefly.currentUri.pathSegments[3];

    // In the composer's «Oggetto» the key is a letter.
    await tester.enterText(field('Oggetto'), '');
    await tester.tap(field('Oggetto'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(Routefly.currentUri.pathSegments[3], draft);
    await close(tester);
  });

  testWidgets('after a crash a Dialog offers the report; accepting opens the Bozza', (tester) async {
    await start(tester, crash: true);
    expect(find.text('Postino si è chiuso in modo imprevisto'), findsOneWidget);
    await tester.tap(find.text('Segnala'));
    await tester.pumpAndSettle();
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(Routefly.currentUri.pathSegments[2], 'bozza');
    expect(fieldText(tester, 'A'), problemReportAddress);
    await close(tester);
  });

  testWidgets('declining the Dialog closes it, and the next start does not offer it again', (tester) async {
    await start(tester, crash: true);
    await tester.tap(find.text('Non ora'));
    await tester.pumpAndSettle();
    expect(find.text('Postino si è chiuso in modo imprevisto'), findsNothing);
    expect(Routefly.currentUri.pathSegments.length, lessThan(3));

    // The next start: the mark is gone.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    await tester.pumpAndSettle();
    expect(find.text('Postino si è chiuso in modo imprevisto'), findsNothing);
  });

  testWidgets('Esc declines the Dialog', (tester) async {
    await start(tester, crash: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Postino si è chiuso in modo imprevisto'), findsNothing);
  });

  testWidgets('without a crash there is no Dialog', (tester) async {
    await start(tester);
    expect(find.text('Postino si è chiuso in modo imprevisto'), findsNothing);
  });
}
