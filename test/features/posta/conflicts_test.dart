// UI dei Conflitti (#148, ADR 0008): banner «N conflitti», elenco, risoluzione, segno nel messaggio.
import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import '../../support/ui.dart';

const _banner = ValueKey('conflicts-banner');

void main() {
  late Harness h;
  late FakeMailProvider a;
  late FakeMailProvider b;

  Future<void> start(WidgetTester tester) async {
    h = await Harness.create();
    a = (await h.addAccount('a', color: 4))..deliver(msg('1', subject: 'Fattura', fromName: 'Ada'));
    b = (await h.addAccount('b', color: 5))..deliver(msg('2', subject: 'Biglietti', fromName: 'Bea'));
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    await tester.pumpAndSettle();
    // Routefly is global: a test that ended on another page must not leak it into the next.
    unawaited(Routefly.navigate('/posta'));
    await tester.pumpAndSettle();
  }

  /// Archivia offline, poi il Provider lo mette nel Cestino: alla riconnessione è un Conflitto.
  Future<void> archiveVsTrash(WidgetTester tester, FakeMailProvider p, String account, String id) async {
    p.goOffline();
    await getIt<SyncEngine>().act(account, [id], const Archive());
    p
      ..changeElsewhere(id, placementAttribute, Placement.trash)
      ..goOnline();
    await getIt<SyncEngine>().syncAll();
    await tester.pumpAndSettle();
  }

  Future<void> openList(WidgetTester tester) async {
    await tester.tap(find.text('Vedi'));
    await tester.pumpAndSettle();
  }

  Finder row(String account, String id) => find.byKey(ValueKey('conflict-$account-$id'));
  Finder inRow(Finder r, Finder f) => find.descendant(of: r, matching: f);
  String title(WidgetTester tester) => tester.widget<PostinoBanner>(find.byKey(_banner)).title;

  group('banner', () {
    testWidgets('counts the Conflitti: all the Accounts in Posta unificata, only its own in an Account', (
      tester,
    ) async {
      await start(tester);
      expect(find.byKey(_banner), findsNothing);

      await archiveVsTrash(tester, a, 'a', '1');
      expect(title(tester), '1 conflitto');
      await archiveVsTrash(tester, b, 'b', '2');
      expect(title(tester), '2 conflitti');

      unawaited(Routefly.navigate('/posta/a'));
      await tester.pumpAndSettle();
      expect(title(tester), '1 conflitto');
    });

    testWidgets('no banner for another attribute changed elsewhere', (tester) async {
      await start(tester);
      a.goOffline();
      await getIt<SyncEngine>().act('a', ['1'], const Archive());
      a
        ..changeElsewhere('1', starredAttribute, true)
        ..goOnline();
      await getIt<SyncEngine>().syncAll();
      await tester.pumpAndSettle();
      expect(find.byKey(_banner), findsNothing);
    });

    testWidgets('no banner for a message that vanished', (tester) async {
      await start(tester);
      b.goOffline();
      await getIt<SyncEngine>().act('b', ['2'], const Archive());
      b
        ..removeRemotely('2')
        ..goOnline();
      await getIt<SyncEngine>().syncAll();
      await tester.pumpAndSettle();
      expect(find.byKey(_banner), findsNothing);
    });

    testWidgets('no banner for Elimina', (tester) async {
      await start(tester);
      a.goOffline();
      await getIt<SyncEngine>().act('a', ['1'], const Delete());
      a
        ..changeElsewhere('1', placementAttribute, Placement.archive)
        ..goOnline();
      await getIt<SyncEngine>().syncAll();
      await tester.pumpAndSettle();
      expect(find.byKey(_banner), findsNothing);
    });
  });

  group('elenco e risoluzione', () {
    testWidgets('a row per Conflitto: Account color, message and the two versions in words', (tester) async {
      await start(tester);
      await archiveVsTrash(tester, a, 'a', '1');
      await archiveVsTrash(tester, b, 'b', '2');
      await openList(tester);

      expect(find.text('2 conflitti'), findsOneWidget, reason: 'the count of the screen');
      for (final (acc, color, subject, sender) in [
        ('a', PostinoAccountColor.values[4], 'Fattura', 'Ada'),
        ('b', PostinoAccountColor.values[5], 'Biglietti', 'Bea'),
      ]) {
        final r = row(acc, acc == 'a' ? '1' : '2');
        expect(r, findsOneWidget);
        expect(tester.widget<PostinoAccountMark>(inRow(r, find.byType(PostinoAccountMark))).color, color);
        expect(inRow(r, find.text(subject)), findsOneWidget);
        expect(inRow(r, find.text(sender)), findsOneWidget);
        expect(inRow(r, find.text('La tua: archiviato')), findsOneWidget);
        expect(inRow(r, find.text('Provider: nel Cestino')), findsOneWidget);
      }
    });

    testWidgets('«La tua» keeps the local value and sends it to the Provider; the row and the banner go', (
      tester,
    ) async {
      await start(tester);
      await archiveVsTrash(tester, a, 'a', '1');
      await archiveVsTrash(tester, b, 'b', '2');
      await openList(tester);

      await tester.tap(inRow(row('a', '1'), find.text('La tua')));
      await tester.pumpAndSettle();

      expect(row('a', '1'), findsNothing);
      expect(row('b', '2'), findsOneWidget);
      expect(find.text('1 conflitto'), findsOneWidget);
      final sent = a.actionCalls.last;
      expect((sent.$1, sent.$2), ('1', const Archive()));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(title(tester), '1 conflitto');
    });

    testWidgets('a resolved row fades and closes out of reach (#283); the last one gives way to the empty state', (
      tester,
    ) async {
      await start(tester);
      await archiveVsTrash(tester, a, 'a', '1');
      await archiveVsTrash(tester, b, 'b', '2');
      await openList(tester);
      final full = tester.getSize(row('a', '1')).height;

      await tester.tap(inRow(row('a', '1'), find.text('La tua')));
      await tester.pump();
      await tester.pump();
      await tester.pump(PostinoMotion.swipeDismiss ~/ 2);
      final fade = find.ancestor(of: row('a', '1'), matching: find.byType(PostinoSizeFade));
      expect(tester.getSize(fade).height, inExclusiveRange(0, full), reason: 'half way it is closing');
      expect(Focus.of(tester.element(inRow(row('a', '1'), find.text('La tua')))).canRequestFocus, isFalse);
      expect(find.text('1 conflitto'), findsOneWidget, reason: 'the count does not wait');
      final next = inRow(row('b', '2'), find.text('La tua'));
      expect(Focus.of(tester.element(next)).hasPrimaryFocus, isTrue, reason: 'the focus goes on at once');
      await tester.pumpAndSettle();
      expect(row('a', '1'), findsNothing);

      final handle = tester.ensureSemantics();
      await tester.tap(next);
      await tester.pump();
      await tester.pump();
      await tester.pump(PostinoMotion.state ~/ 2);
      final empty = find.text('Nessun conflitto');
      expect(empty, findsOneWidget, reason: 'the empty state fades in at once');
      expect(primaryFocus?.debugLabel, 'Nessun conflitto', reason: 'the focus lands on it at once');
      expect(find.semantics.byLabel(RegExp('La tua')), findsNothing, reason: 'the leaving list is not read');
      await tester.pumpAndSettle();
      expect(row('b', '2'), findsNothing);
      expect(primaryFocus?.debugLabel, 'Nessun conflitto');
      handle.dispose();
    });

    testWidgets('with reduced motion a resolved row goes at once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await start(tester);
      await archiveVsTrash(tester, a, 'a', '1');
      await archiveVsTrash(tester, b, 'b', '2');
      await openList(tester);
      await tester.tap(inRow(row('a', '1'), find.text('La tua')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(row('a', '1'), findsNothing);
    });

    testWidgets('«Del Provider» takes the Provider value here and writes nothing on the Provider', (tester) async {
      await start(tester);
      await archiveVsTrash(tester, a, 'a', '1');
      final calls = a.actionCalls.length;
      await openList(tester);

      await tester.tap(find.text('Del Provider'));
      await tester.pumpAndSettle();

      expect(find.text('Nessun conflitto'), findsOneWidget);
      expect(a.actionCalls, hasLength(calls));
      final here = await tester.runAsync(() => getIt<InboxRepository>().watchMessage('a', '1').first);
      expect(valueOf(here!, placementAttribute), Placement.trash);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_banner), findsNothing, reason: 'gone at 0');
    });
  });

  group('segno nel messaggio', () {
    testWidgets('the row stays in the list with its local version and a sign, until resolved', (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      a.goOffline();
      await getIt<SyncEngine>().act('a', ['1'], const MarkRead());
      await getIt<SyncEngine>().act('a', ['1'], const MarkUnread());
      a
        ..changeElsewhere('1', readAttribute, true)
        ..goOnline();
      await getIt<SyncEngine>().syncAll();
      await tester.pumpAndSettle();

      final r = find.byKey(const ValueKey('row-a-1'));
      expect(r, findsOneWidget);
      expect(inRow(r, find.byKey(const ValueKey('unread'))), findsOneWidget, reason: 'the local version: unread');
      expect(inRow(r, icon(PostinoIcons.alert)), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Semantics && (w.properties.label ?? '').contains('In conflitto')),
        findsOneWidget,
        reason: 'the row says it out loud',
      );
      expect(find.byKey(const ValueKey('row-b-2')), findsOneWidget);
      expect(inRow(find.byKey(const ValueKey('row-b-2')), icon(PostinoIcons.alert)), findsNothing);

      await openList(tester);
      await tester.tap(find.text('Del Provider'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(inRow(r, icon(PostinoIcons.alert)), findsNothing);
      expect(inRow(r, find.byKey(const ValueKey('unread'))), findsNothing, reason: 'now the Provider version');
      handle.dispose();
    });

    testWidgets('the open Conversazione shows the notice and resolves it in place', (tester) async {
      await start(tester);
      await archiveVsTrash(tester, a, 'a', '1');

      unawaited(Routefly.navigate('/posta/a/conversazione/t-1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('In conflitto: Ada'), findsOneWidget);
      expect(find.textContaining('La tua: archiviato'), findsOneWidget);

      await tester.tap(find.text('La tua'));
      await tester.pumpAndSettle();
      expect(find.textContaining('In conflitto'), findsNothing);
    });

    testWidgets('two Conflitti in one Conversazione: each notice names its message by sender and date', (tester) async {
      await start(tester);
      a.deliver(
        msg('3', conversationId: 't-1', from: 'bob@example.com', fromName: 'Bob', date: DateTime.utc(2025, 12)),
      );
      await getIt<SyncEngine>().syncAll();
      a.goOffline();
      await getIt<SyncEngine>().act('a', ['1', '3'], const Archive());
      a
        ..changeElsewhere('1', placementAttribute, Placement.trash)
        ..changeElsewhere('3', placementAttribute, Placement.trash)
        ..goOnline();
      await getIt<SyncEngine>().syncAll();
      await tester.pumpAndSettle();

      unawaited(Routefly.navigate('/posta/a/conversazione/t-1'));
      await tester.pumpAndSettle();

      expect(find.text('In conflitto: Ada, 1 gen'), findsOneWidget);
      expect(find.text('In conflitto: Bob, 1 dic 2025'), findsOneWidget);
    });
  });

  group('accessibilità', () {
    testWidgets('keyboard: Tab reaches «Vedi», Enter opens, Esc goes back, focus lands on the next row', (
      tester,
    ) async {
      await start(tester);
      await archiveVsTrash(tester, a, 'a', '1');
      await archiveVsTrash(tester, b, 'b', '2');

      final vedi = find.text('Vedi');
      for (var i = 0; i < 100 && !Focus.of(tester.element(vedi)).hasPrimaryFocus; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(Focus.of(tester.element(vedi)).hasPrimaryFocus, isTrue, reason: 'the banner button takes the focus');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(row('a', '1'), findsOneWidget);

      await tester.tap(inRow(row('a', '1'), find.text('La tua')));
      await tester.pumpAndSettle();
      final next = inRow(row('b', '2'), find.text('La tua'));
      expect(Focus.of(tester.element(next)).hasPrimaryFocus, isTrue, reason: 'focus restored after the resolution');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_banner), findsOneWidget);
      expect(row('b', '2'), findsNothing, reason: 'back on the inbox');
    });

    testWidgets('banner and rows are announced: live region, count, versions in the label', (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      await archiveVsTrash(tester, a, 'a', '1');

      final banner = tester.getSemantics(find.text('1 conflitto'));
      expect(banner.flagsCollection.isLiveRegion, isTrue);
      expect(find.bySemanticsLabel(RegExp('1 conflitto')), findsWidgets);

      await openList(tester);
      expect(
        find.bySemanticsLabel('Ada, Fattura, account a@example.com, La tua: archiviato, Provider: nel Cestino'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('at 200% text the list still lays out', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await start(tester);
      await archiveVsTrash(tester, a, 'a', '1');
      await openList(tester);

      expect(row('a', '1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
