// UI dei Conflitti delle Bozze (#149): banner, le due versioni affiancate, «La tua» / «Del Provider».
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _id = '<x@example.com>';
const _row = ValueKey('draft-conflict-a-$_id');

OutgoingMessage _draft(String subject, String body) =>
    OutgoingMessage(messageId: _id, from: 'a@example.com', to: const ['b@example.com'], subject: subject, body: body);

/// Runs [f] to its end: the engine's database work needs both the test's frames and real time.
Future<T> drive<T>(WidgetTester tester, Future<T> f) async {
  var done = false;
  unawaited(f.whenComplete(() => done = true));
  // Even when [f] is already done, a few rounds let what it started (a replay, a stream) land.
  for (var i = 0; i < 100 && (!done || i < 5); i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
  return f;
}

void main() {
  late Harness h;
  late FakeMailProvider a;

  /// A Bozza uploaded once, then edited «on two devices»: elsewhere, and here offline; back online it is a Conflitto.
  Future<void> start(WidgetTester tester) async {
    h = await Harness.create();
    a = await h.addAccount('a', color: 4);
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    await tester.pumpAndSettle();
    unawaited(Routefly.navigate('/posta'));
    await tester.pumpAndSettle();
    final engine = getIt<SyncEngine>();
    await drive(tester, engine.saveDraft('a', _draft('Cena', '<p>Alle 8</p>')));
    await drive(tester, engine.flushDrafts('a'));
    a
      ..goOffline()
      ..deliverDraft(_draft('Cena', '<p>Alle 9, da Gino</p>'));
    await drive(tester, engine.saveDraft('a', _draft('Cena sabato', '<p>Alle 8 e mezza</p>')));
    a.goOnline();
    await drive(tester, engine.flushDrafts('a'));
    await tester.pumpAndSettle();
  }

  Future<void> openList(WidgetTester tester) async {
    await tester.tap(find.text('Vedi'));
    await tester.pumpAndSettle();
  }

  Finder inRow(Finder f) => find.descendant(of: find.byKey(_row), matching: f);

  testWidgets('the banner counts the Bozza; the list shows both versions side by side', (tester) async {
    await start(tester);
    expect(tester.widget<PostinoBanner>(find.byKey(const ValueKey('conflicts-banner'))).title, '1 conflitto');
    await openList(tester);

    final mine = find.byKey(const ValueKey('draft-mine'));
    final theirs = find.byKey(const ValueKey('draft-provider'));
    expect(find.descendant(of: mine, matching: find.text('Cena sabato')), findsOneWidget);
    expect(find.descendant(of: mine, matching: find.text('Alle 8 e mezza')), findsOneWidget);
    expect(find.descendant(of: theirs, matching: find.text('Cena')), findsOneWidget);
    expect(find.descendant(of: theirs, matching: find.text('Alle 9, da Gino')), findsOneWidget);
    // Side by side.
    expect(tester.getTopLeft(mine).dy, tester.getTopLeft(theirs).dy);
    expect(tester.getTopLeft(mine).dx, lessThan(tester.getTopLeft(theirs).dx));

    // Before the choice nothing is lost: the Provider keeps its version, the Composizione the one here.
    expect(a.drafts[_id]!.body, '<p>Alle 9, da Gino</p>');
    final opened = await drive(tester, getIt<SyncEngine>().openDraft('a', _id));
    expect(opened, isA<Ok<OutgoingMessage>>().having((r) => r.value.body, 'body', '<p>Alle 8 e mezza</p>'));
  });

  testWidgets('«La tua» updates the Provider with the Bozza here; the row and the banner go', (tester) async {
    await start(tester);
    await openList(tester);
    await tester.tap(inRow(find.byKey(const ValueKey('keep-mine'))));
    await drive(tester, Future<void>.value());
    await tester.pumpAndSettle();

    expect(find.byKey(_row), findsNothing);
    expect((a.drafts[_id]!.subject, a.drafts[_id]!.body), ('Cena sabato', '<p>Alle 8 e mezza</p>'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conflicts-banner')), findsNothing);
  });

  testWidgets('«Del Provider» overwrites the Bozza here, nothing written on the Provider', (tester) async {
    await start(tester);
    await openList(tester);
    final calls = a.draftCalls.length;
    await tester.tap(inRow(find.byKey(const ValueKey('keep-provider'))));
    await drive(tester, Future<void>.value());
    await tester.pumpAndSettle();

    expect(find.byKey(_row), findsNothing);
    expect(a.draftCalls, hasLength(calls));
    final drafts = await drive(tester, getIt<InboxRepository>().watchDrafts('a').first);
    expect((drafts.single.subject, drafts.single.snippet), ('Cena', 'Alle 9, da Gino'));
  });

  testWidgets('accessibility: each version has its own label and a Tab stop, then the choices', (tester) async {
    final handle = tester.ensureSemantics();
    await start(tester);
    await openList(tester);

    expect(find.bySemanticsLabel('Bozza, account a@example.com'), findsOneWidget);
    expect(find.bySemanticsLabel('La tua versione: oggetto Cena sabato, testo Alle 8 e mezza'), findsOneWidget);
    expect(find.bySemanticsLabel('Versione del Provider: oggetto Cena, testo Alle 9, da Gino'), findsOneWidget);

    bool focused(Finder f) => Focus.of(tester.element(f)).hasPrimaryFocus;
    Finder version(String key) =>
        find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(PostinoFocusRing));
    final mine = version('draft-mine');
    for (var i = 0; i < 50 && !focused(mine); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focused(mine), isTrue, reason: '«La tua» is a Tab stop');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(version('draft-provider')), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(inRow(find.text('La tua').last)), isTrue, reason: 'then the choices');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await drive(tester, Future<void>.value());
    await tester.pumpAndSettle();
    expect(find.byKey(_row), findsNothing);
    handle.dispose();
  });

  testWidgets('at 200% text the two versions still lay out', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await start(tester);
    await openList(tester);
    expect(find.byKey(_row), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
