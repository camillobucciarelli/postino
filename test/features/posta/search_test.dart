// The local search (#205): opened from the bar or `/`, results while typing, a result opens its Conversazione,
// scope, keyboard and screen reader.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import '../../support/ui.dart';

const _desktop = Size(1600, 900);
const _phone = Size(390, 844);

/// Two Accounts: a1 with an invoice and a meeting, a2 with another invoice.
Future<void> _start(WidgetTester tester, {Size size = _desktop}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  (await h.addAccount('a1'))
    ..deliver(msg('m1', subject: 'Fattura di ottobre', from: 'ada@example.test', date: DateTime.utc(2026, 10, 2)))
    ..deliver(msg('m2', subject: 'Riunione', from: 'bruno@example.test', date: DateTime.utc(2026, 10, 3)));
  (await h.addAccount('a2'))
      .deliver(msg('n1', subject: 'Fattura fornitore', from: 'carla@example.test', date: DateTime.utc(2026, 10, 4)));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  // Routefly keeps the last navigation in statics.
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

Future<void> _openFromBar(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Cerca'));
  await tester.pumpAndSettle();
}

/// Types in the search field and waits for the results, with no Enter.
Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

Finder _row(String account, String id) => find.byKey(ValueKey('row-$account-$id'));

void main() {
  testWidgets('the Cerca button opens the field, ready to type; results come while typing, with no Enter', (
    tester,
  ) async {
    await _start(tester);
    await _openFromBar(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    expect(find.text('Cerca nella posta'), findsWidgets, reason: 'the field name and the idle hint');
    expect(_row('a1', 'm1'), findsNothing, reason: 'nothing to look for yet');

    await _type(tester, 'fattur');
    expect(_row('a1', 'm1'), findsOneWidget);
    expect(_row('a2', 'n1'), findsOneWidget);
    expect(_row('a1', 'm2'), findsNothing);
    // Newest first, Accounts mixed.
    expect(tester.getTopLeft(_row('a2', 'n1')).dy < tester.getTopLeft(_row('a1', 'm1')).dy, isTrue);

    await _type(tester, 'da:bruno');
    expect(_row('a1', 'm2'), findsOneWidget);
    expect(_row('a1', 'm1'), findsNothing);
  });

  testWidgets('nothing found says so', (tester) async {
    await _start(tester);
    await _openFromBar(tester);
    await _type(tester, 'inesistente');
    expect(find.text('Nessun risultato'), findsOneWidget);
    expect(find.byKey(const ValueKey('row-a1-m1')), findsNothing);
  });

  testWidgets('from an Account the search stays in it', (tester) async {
    await _start(tester);
    unawaited(Routefly.navigate(routePaths.posta.$accountId.path.changes({'accountId': 'a1'})));
    await tester.pumpAndSettle();
    await _openFromBar(tester);
    await _type(tester, 'fattura');
    expect(_row('a1', 'm1'), findsOneWidget);
    expect(_row('a2', 'n1'), findsNothing);
  });

  testWidgets('a result opens its Conversazione beside the results; Esc closes it and the results stay', (
    tester,
  ) async {
    await _start(tester);
    await _openFromBar(tester);
    await _type(tester, 'fattura');
    await tester.tap(_row('a1', 'm1'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsOneWidget);
    expect(_row('a2', 'n1'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsNothing);
    expect(_row('a1', 'm1'), findsOneWidget);
  });

  testWidgets('on a phone a result opens a full page; Indietro returns to the search, text and results intact', (
    tester,
  ) async {
    await _start(tester, size: _phone);
    await _openFromBar(tester);
    await _type(tester, 'fattura');
    await tester.tap(_row('a1', 'm1'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsOneWidget);

    await tester.tap(icon(PostinoIcons.arrowLeft).last);
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsNothing);
    expect(find.text('fattura'), findsOneWidget, reason: 'the field keeps what was typed');
    expect(_row('a1', 'm1'), findsOneWidget);
    expect(_row('a2', 'n1'), findsOneWidget);
  });

  testWidgets('the system Indietro closes the open Conversazione first; the search and its results stay', (
    tester,
  ) async {
    await _start(tester, size: _phone);
    await _openFromBar(tester);
    await _type(tester, 'fattura');
    await tester.tap(_row('a1', 'm1'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(_row('a1', 'm1'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing, reason: 'the second Indietro leaves the search');
  });

  testWidgets('on a narrow window `/` from an open Conversazione returns to the visible field', (tester) async {
    await _start(tester, size: _phone);
    await _openFromBar(tester);
    await _type(tester, 'fattura');
    await tester.tap(_row('a1', 'm1'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsOneWidget);

    Focus.of(
      tester.element(find.descendant(of: find.byType(ConversationView), matching: find.byType(PostinoFocusRing)).first),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsNothing);
    final fn = tester.widget<EditableText>(find.byType(EditableText)).focusNode;
    expect(fn.hasFocus, isTrue);
  });

  testWidgets('Esc empties the field, the second Esc leaves the search', (tester) async {
    await _start(tester);
    await _openFromBar(tester);
    await _type(tester, 'fattura');
    expect(_row('a1', 'm1'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
    expect(_row('a1', 'm1'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing, reason: 'back on the Posta unificata');
    expect(_row('a1', 'm2'), findsOneWidget);
  });

  testWidgets('`/` opens the search from the list, and puts the focus in the field from the results', (tester) async {
    await _start(tester);
    await tester.tap(_row('a1', 'm2'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await _type(tester, 'fattura');
    // Down goes to the results, and `/` back to the field; typed in the field it is a character.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isFalse);
    final onRow = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<PostinoMessageTile>();
    expect(onRow, isNotNull, reason: 'Freccia giù from the field lands on a result');
    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ, character: 'j');
    await tester.pumpAndSettle();
    expect(
      find.byType(ConversationView),
      findsNothing,
      reason: 'j in the field is a letter, not Successiva (ADR 0014)',
    );
  });

  testWidgets('the field is named for the screen reader and the number of results is a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await _start(tester);
    await _openFromBar(tester);
    final field = tester.getSemantics(find.byType(TextField));
    expect(field.label, 'Cerca nella posta');
    expect(field.flagsCollection.isTextField, isTrue);
    final live = find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true);
    await _type(tester, 'fattura');
    expect(tester.getSemantics(live).label, '2 risultati');
    await _type(tester, 'inesistente');
    expect(tester.getSemantics(live).label, 'Nessun risultato');
    handle.dispose();
  });
}
