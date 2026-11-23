// The screen of «Mostra tutti» (#366, the twin of inbox_section_screen.dart for the mutation test): the page
// shortcuts of the Posta, the return from a Conversazione on a narrow window, the system's Indietro (ADR 0024).
import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/composizione/presentation/composer_view.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/features/posta/presentation/inbox_section_screen.dart';
import 'package:postino/features/posta/presentation/search_screen.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/harness.dart';
import '../../../support/system_back.dart';

late SystemBack _system;

/// Unread `u1..u4` (the newest first) and read `r1`, then «Mostra tutti» of Da leggere, from the Posta unificata or
/// from the inbox of [accountId].
Future<FakeMailProvider> _start(WidgetTester tester, {double width = 1600, String? accountId}) async {
  _system = SystemBack.install(tester);
  tester.view
    ..physicalSize = Size(width, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  final p = await h.addAccount('a1');
  for (var i = 1; i <= 4; i++) {
    p.deliver(msg('u$i', subject: 'Oggetto u$i', date: DateTime.utc(2026, 10, 1, 9, 60 - i), conversationId: 't-u$i'));
  }
  p.deliver(msg('r1', subject: 'Letto', date: DateTime.utc(2026, 10, 1, 8), conversationId: 't-r1', isRead: true));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  // Routefly keeps the last navigation in statics.
  unawaited(
    Routefly.navigate(
      accountId == null ? routePaths.posta.path : routePaths.posta.$accountId.path.changes({'accountId': accountId}),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(PostinoButton, 'Mostra tutti'));
  await tester.pumpAndSettle();
  expect(find.byType(InboxSectionScreen), findsOneWidget);
  return p;
}

Finder _row(String id) =>
    find.descendant(of: find.byType(InboxSectionScreen), matching: find.byKey(ValueKey('row-a1-$id')));

String? _focusedId() {
  final key = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<PostinoMessageTile>()?.key;
  return key is ValueKey<String> ? key.value.split('-').last : null;
}

Future<void> _focusRow(WidgetTester tester, String id) async {
  Focus.of(tester.element(find.descendant(of: _row(id), matching: find.byType(PostinoFocusRing)))).requestFocus();
  await tester.pumpAndSettle();
}

void main() {
  group('the page shortcuts of the Posta', () {
    testWidgets('c writes a new message from the Account of the screen', (tester) async {
      await _start(tester, accountId: 'a1');
      await _focusRow(tester, 'u1');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'c');
      await tester.pumpAndSettle();
      expect(find.byType(ComposerView), findsOneWidget);
    });

    for (final (accountId, scope) in [('a1', 'a1@example.com'), (null, 'Tutti gli Account')]) {
      testWidgets('/ searches in the scope of the screen: $scope', (tester) async {
        await _start(tester, accountId: accountId);
        await _focusRow(tester, 'u1');
        await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
        await tester.pumpAndSettle();
        expect(find.byType(SearchScreen), findsOneWidget);
        expect(tester.widget<PostinoAppBar>(find.byType(PostinoAppBar).last).subtitle, scope);
        // Routefly keeps its stack in statics: the next test starts from the Posta alone.
        for (final _ in [1, 2]) {
          await _system.press(tester);
        }
        expect(find.byType(InboxSectionScreen), findsNothing);
      });
    }

    testWidgets('Ctrl+R refreshes', (tester) async {
      final p = await _start(tester);
      await _focusRow(tester, 'u1');
      final before = p.syncCalls;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(p.syncCalls, before + 1);
    });
  });

  testWidgets('on a narrow window the Conversazione closed comes back to its row, which moves on the next move', (
    tester,
  ) async {
    await _start(tester, width: 800);
    await tester.tap(_row('u2'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsNothing);
    expect(find.byType(InboxSectionScreen), findsOneWidget);
    expect(_row('u2'), findsOneWidget, reason: 'read now, its row keeps the focus back from the Conversazione');
    expect(_focusedId(), 'u2');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(_focusedId(), 'u3');
    expect(_row('u2'), findsNothing, reason: 'the focus moved on: it is in Letti now');
  });

  testWidgets('the system Indietro clears a selection first, then closes the Conversazione, then the screen', (
    tester,
  ) async {
    await _start(tester, width: 390);
    await tester.tap(_row('u2'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Oggetto u2').last);
    await tester.pumpAndSettle();
    bool selected() =>
        Actions.maybeFind<PostinoClearSelectionIntent>(primaryFocus!.context!)
            ?.isEnabled(const PostinoClearSelectionIntent()) ??
        false;
    expect(selected(), isTrue);

    await _system.press(tester);
    expect(find.byType(ConversationView), findsOneWidget);
    expect(selected(), isFalse);

    await _system.press(tester);
    expect(find.byType(ConversationView), findsNothing);
    expect(find.byType(InboxSectionScreen), findsOneWidget);

    await _system.press(tester);
    expect(find.byType(InboxSectionScreen), findsNothing);
    expect(_system.exits, 0);
  });
}
