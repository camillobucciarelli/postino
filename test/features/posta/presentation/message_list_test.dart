// The list of Conversazioni (the twin of message_list.dart for the mutation test): the cursor follows a focus that
// came some other way, and the number of rows is reported when it changes.
import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/message_list.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/harness.dart';

/// Rows `m1` to `m5`, newest first: `m5` is the first row.
Future<FakeMailProvider> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1600, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  final p = await h.addAccount('a1');
  for (var i = 1; i <= 5; i++) {
    p.deliver(msg('m$i', subject: 'Fattura $i', date: DateTime.utc(2026, 10, 1, 9, i), conversationId: 't$i'));
  }
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  // Routefly keeps the last navigation in statics.
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  return p;
}

/// The number of the row that has the focus, null when focus is elsewhere.
int? _focusedRow() {
  final key = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<PostinoMessageTile>()?.key;
  return key is ValueKey<String> ? int.parse(key.value.split('-m').last) : null;
}

Future<void> _focus(WidgetTester tester, int i) async {
  final row = find.descendant(of: find.byKey(ValueKey('row-a1-m$i')), matching: find.byType(PostinoFocusRing));
  Focus.of(tester.element(row)).requestFocus();
  await tester.pumpAndSettle();
  expect(_focusedRow(), i);
}

Future<void> _removeRemotely(WidgetTester tester, FakeMailProvider p, Iterable<int> ids) async {
  for (final i in ids) {
    p.removeRemotely('m$i');
  }
  await getIt<SyncEngine>().syncAll();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the focused row leaves the list: the focus goes to the row now in its place, and j / k go on', (
    tester,
  ) async {
    final p = await _start(tester);
    await _focus(tester, 3);
    await _removeRemotely(tester, p, [3]);
    expect(_focusedRow(), 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(_focusedRow(), 1, reason: 'from the row that took the place, not from the first');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(_focusedRow(), 2);
  });

  testWidgets('the last row leaves the list: the focus goes to the one before', (tester) async {
    final p = await _start(tester);
    await _focus(tester, 1);
    await _removeRemotely(tester, p, [1]);
    expect(_focusedRow(), 2);
  });

  testWidgets('a focus that is not on the list is not taken when the cursor row leaves', (tester) async {
    final p = await _start(tester);
    await _focus(tester, 3);
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(_focusedRow(), isNull);
    await _removeRemotely(tester, p, [3]);
    expect(_focusedRow(), isNull);
  });

  testWidgets('the list empties: nothing breaks, and a row coming back shows', (tester) async {
    final p = await _start(tester);
    await _focus(tester, 3);
    await _removeRemotely(tester, p, [1, 2, 3, 4, 5]);
    expect(find.byType(PostinoMessageTile), findsNothing);
    p.deliver(msg('m9', subject: 'Nuova', date: DateTime.utc(2026, 10, 2), conversationId: 't9'));
    await getIt<SyncEngine>().syncAll();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('row-a1-m9')), findsOneWidget);
  });

  testWidgets('a row focused some other way becomes the cursor: the next move starts from it', (tester) async {
    await _start(tester);
    expect(find.byType(MessageList), findsOneWidget);
    Future<void> focus(int i) async {
      final row = find.descendant(of: find.byKey(ValueKey('row-a1-m$i')), matching: find.byType(PostinoFocusRing));
      Focus.of(tester.element(row)).requestFocus();
      await tester.pumpAndSettle();
      expect(_focusedRow(), i);
    }

    await focus(4);
    await focus(3);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(_focusedRow(), 2, reason: 'one row on from the one focused, not from the first');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(_focusedRow(), 1, reason: 'and on again: a row that lost the focus is not the cursor');
  });

  testWidgets('the number of results of the search is announced, and again when it changes', (tester) async {
    final handle = tester.ensureSemantics();
    await _start(tester);
    await tester.tap(find.byTooltip('Cerca'));
    await tester.pumpAndSettle();
    final live = find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true);

    await tester.enterText(find.byType(TextField), 'fattura');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(live).label, '5 risultati');

    await tester.enterText(find.byType(TextField), 'fattura 3');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(live).label, '1 risultato');
    handle.dispose();
  });
}
