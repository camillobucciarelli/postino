// The search on the Providers (#207): only with Invio, its finds join the local results and open as a whole
// Conversazione; «Cerco anche su…», the notice for an Account not reachable, «Mostra altri», Da ricollegare.

import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/provider_search_use_case.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

/// Two Accounts: a1 with a recent invoice and, on the Provider only, a contract of 200 days ago; a2 empty.
Future<(Harness, FakeMailProvider, FakeMailProvider)> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1600, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  final a1 = (await h.addAccount('a1'))
    ..deliver(msg('m1', subject: 'Fattura di ottobre', date: DateTime.utc(2026, 10, 2)))
    ..deliverOutsideWindow(
      msg(
        'old',
        subject: 'Contratto di affitto',
        conversationId: 't-old',
        date: h.clock.now().subtract(const Duration(days: 200)),
      ),
    )
    ..deliverOutsideWindow(
      msg(
        'old-reply',
        subject: 'Re: Contratto di affitto',
        conversationId: 't-old',
        date: h.clock.now().subtract(const Duration(days: 199)),
      ),
    );
  final a2 = await h.addAccount('a2');
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Cerca'));
  await tester.pumpAndSettle();
  return (h, a1, a2);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

/// Invio in the field. The search reads the database, which answers outside the fake time: a few real pauses let it
/// reach the Providers and write; [settle] false stops there, with a search still held.
Future<void> _enter(WidgetTester tester, {bool settle = true}) async {
  await tester.testTextInput.receiveAction(TextInputAction.search);
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  if (settle) await tester.pumpAndSettle();
}

Finder _row(String account, String id) => find.byKey(ValueKey('row-$account-$id'));

void main() {
  testWidgets('an old message is found only after Invio, opens as a whole Conversazione, back returns to it', (
    tester,
  ) async {
    final (h, a1, _) = await _start(tester);
    await _type(tester, 'affitto');
    expect(_row('a1', 'old-reply'), findsNothing, reason: 'while typing only the local search');
    expect(a1.searchCalls, isEmpty);

    await _enter(tester);
    expect(_row('a1', 'old-reply'), findsOneWidget, reason: 'one row per Conversazione, its newest message');
    expect(h.notifications.shown, isEmpty, reason: 'no notification for what a search brought');

    await tester.tap(_row('a1', 'old-reply'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsOneWidget);
    expect(find.text('Contratto di affitto'), findsWidgets);
    expect(find.text('Re: Contratto di affitto'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsNothing);
    expect(_row('a1', 'old-reply'), findsOneWidget);
  });

  testWidgets('«Cerco anche su…» per Account while it is asked, a live region; then it goes', (tester) async {
    final handle = tester.ensureSemantics();
    final (_, _, a2) = await _start(tester);
    final slow = a2.holdSearch = Completer<void>();
    await _type(tester, 'affitto');
    await _enter(tester, settle: false);
    await tester.pump();
    final banner = find.textContaining('Cerco anche su a2@example.com…');
    expect(banner, findsOneWidget);
    expect(find.textContaining('Cerco anche su a1@example.com…'), findsNothing, reason: 'a1 already answered');
    final live = find.ancestor(
      of: banner,
      matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true),
    );
    expect(live, findsWidgets);

    slow.complete();
    await tester.pumpAndSettle();
    expect(banner, findsNothing);
    handle.dispose();
  });

  testWidgets('a Provider that stopped at its cap says so, in a live region (#209)', (tester) async {
    final handle = tester.ensureSemantics();
    final (_, a1, _) = await _start(tester);
    a1.searchLimit = 1000;
    await _type(tester, 'affitto');
    await _enter(tester);
    final banner = find.textContaining('Mostrati i primi 1.000 risultati di a1@example.com');
    expect(banner, findsOneWidget);
    expect(find.textContaining('risultati di a2@example.com'), findsNothing);
    expect(
      find.ancestor(
        of: banner,
        matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true),
      ),
      findsWidgets,
    );
    await _type(tester, 'fattura');
    expect(banner, findsNothing, reason: 'a new text drops it');
    handle.dispose();
  });

  testWidgets('offline: the local results stay, with a notice for the Account; the other one answers', (tester) async {
    final (_, a1, _) = await _start(tester);
    a1.goOffline();
    await _type(tester, 'fattura');
    await _enter(tester);
    expect(_row('a1', 'm1'), findsOneWidget);
    expect(find.textContaining('Risultati solo locali: a1@example.com non è raggiungibile'), findsOneWidget);
    expect(find.textContaining('a2@example.com non è'), findsNothing);
  });

  testWidgets('an Account slower than the timeout gets the notice, the other one\'s finds stay', (tester) async {
    final (_, _, a2) = await _start(tester);
    a2.holdSearch = Completer<void>();
    await _type(tester, 'affitto');
    await _enter(tester, settle: false);
    await tester.pump(providerSearchTimeout + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('Risultati solo locali: a2@example.com non è raggiungibile'), findsOneWidget);
    expect(_row('a1', 'old-reply'), findsOneWidget);
  });

  testWidgets('a Da ricollegare Account is not asked; a refused login makes it Da ricollegare', (tester) async {
    final (_, a1, a2) = await _start(tester);
    await GetIt.I<MailStore>().setStatus('a2', AccountStatus.daRicollegare);
    a1.breakAuth();
    await _type(tester, 'affitto');
    await _enter(tester);
    expect(a2.searchCalls, isEmpty);
    expect(a1.searchCalls, hasLength(1));
    final status = {for (final a in await GetIt.I<MailStore>().accounts()) a.id: a.status};
    expect(status['a1'], AccountStatus.daRicollegare);
  });

  testWidgets('«Mostra altri» brings the next page; a button reached with Tab, pressed with Spazio and Invio', (
    tester,
  ) async {
    final (_, a1, _) = await _start(tester);
    for (var i = 0; i < 5; i++) {
      a1.deliverOutsideWindow(msg('p$i', subject: 'Preventivo $i', date: DateTime.utc(2026, 3, 1 + i)));
    }
    await _type(tester, 'preventivo');
    await _enter(tester);
    expect(_row('a1', 'p4'), findsOneWidget);
    expect(_row('a1', 'p3'), findsOneWidget);
    expect(_row('a1', 'p2'), findsNothing);

    final more = find.widgetWithText(TextButton, 'Mostra altri');
    expect(more, findsOneWidget);
    expect(tester.getSemantics(more).flagsCollection.isButton, isTrue);
    // Reached with Tab from the field.
    bool focused() => Focus.of(tester.element(find.text('Mostra altri'))).hasFocus;
    for (var i = 0; i < 6 && !focused(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focused(), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await _settle(tester);
    expect(_row('a1', 'p2'), findsOneWidget);
    expect(_row('a1', 'p0'), findsNothing);
    expect(focused(), isTrue, reason: 'the button stayed while its page loaded');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(_row('a1', 'p0'), findsOneWidget);
    expect(find.text('Mostra altri'), findsNothing, reason: 'the last page');
  });

  testWidgets('a next page that fails keeps its place: «Mostra altri» asks it again, the results stay', (tester) async {
    final (_, a1, _) = await _start(tester);
    for (var i = 0; i < 5; i++) {
      a1.deliverOutsideWindow(msg('p$i', subject: 'Preventivo $i', date: DateTime.utc(2026, 3, 1 + i)));
    }
    await _type(tester, 'preventivo');
    await _enter(tester);
    expect(_row('a1', 'p3'), findsOneWidget);

    a1.goOffline();
    await tester.tap(find.text('Mostra altri'));
    await _settle(tester);
    expect(find.textContaining('a1@example.com non è raggiungibile'), findsOneWidget);
    expect(_row('a1', 'p4'), findsOneWidget, reason: 'what was found stays');
    expect(find.text('Mostra altri'), findsOneWidget, reason: 'the page can be asked again');

    a1.goOnline();
    await tester.tap(find.text('Mostra altri'));
    await _settle(tester);
    expect(_row('a1', 'p2'), findsOneWidget);
    expect(_row('a1', 'p1'), findsOneWidget);
    expect(_row('a1', 'p4'), findsOneWidget);
    expect(find.textContaining('non è raggiungibile'), findsNothing);
    expect(a1.searchCalls.map((c) => c.$2), [null, '2', '2']);
  });

  testWidgets('a new text drops what the Providers found for the old one', (tester) async {
    await _start(tester);
    await _type(tester, 'affitto');
    await _enter(tester);
    expect(_row('a1', 'old-reply'), findsOneWidget);
    await _type(tester, 'affitto x');
    expect(_row('a1', 'old-reply'), findsNothing, reason: 'not a find of «affitto x», nor a local match');
    await _type(tester, 'affitto');
    expect(_row('a1', 'old-reply'), findsOneWidget, reason: 'stored here now: the local search finds it');
  });

  testWidgets('a refused login or a pause of the Provider is not offered Invio as a cure', (tester) async {
    final (h, a1, a2) = await _start(tester);
    a1.breakAuth();
    a2.rateLimit(retryAfter: h.clock.now().add(const Duration(minutes: 5)));
    await _type(tester, 'affitto');
    await _enter(tester);
    expect(find.textContaining('Va ricollegato'), findsOneWidget);
    expect(find.textContaining('chiesto una pausa'), findsOneWidget);
    expect(find.textContaining('Premi Invio'), findsNothing);
  });

  testWidgets('a recent message the Provider finds is left to the sync (which notifies it)', (tester) async {
    final (h, a1, _) = await _start(tester);
    a1.deliver(msg('new', subject: 'Contratto firmato, affitto', date: h.clock.now()), signal: false);
    await _type(tester, 'affitto');
    await _enter(tester);
    final ids = await tester.runAsync(() => GetIt.I<MailStore>().messageIds('a1'));
    expect(ids, isNot(contains('new')), reason: 'not stored by the search; provider_search_sync_test checks the sync');
    expect(_row('a1', 'old-reply'), findsOneWidget);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
