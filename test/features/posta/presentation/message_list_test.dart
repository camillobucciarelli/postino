// The list of Conversazioni (the twin of message_list.dart for the mutation test): the cursor follows a focus that
// came some other way, and the number of rows is reported when it changes.
import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/message_list.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/harness.dart';

/// Rows `m1` to `m5`, newest first: `m5` is the first row.
Future<void> _start(WidgetTester tester) async {
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
}

/// The number of the row that has the focus, null when focus is elsewhere.
int? _focusedRow() {
  final key = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<PostinoMessageTile>()?.key;
  return key is ValueKey<String> ? int.parse(key.value.split('-m').last) : null;
}

void main() {
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
