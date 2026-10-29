// Posta unificata stays current with changes made elsewhere (ADR 0008): change signal,
// 60 s polling, network return, pull-to-refresh, app resume.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _id = 'a1';
const _a = ValueKey('row-$_id-a');
const _b = ValueKey('row-$_id-b');
const _offline = ValueKey('offline-indicator');

Finder _in(ValueKey<String> row, Finder f) =>
    find.descendant(of: find.byKey(row), matching: f);

void main() {
  late Harness h;
  late FakeMailProvider gmail;

  Future<void> start(WidgetTester tester) async {
    h = await Harness.create();
    gmail = (await h.addAccount(_id))..deliver(msg('a'));
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    await tester.pumpAndSettle();
    expect(find.byKey(_a), findsOneWidget);
  }

  testWidgets(
    'a new message, a read and a Stella made elsewhere show up after the change signal',
    (tester) async {
      await start(tester);
      expect(_in(_a, find.byKey(const ValueKey('unread'))), findsOneWidget);
      expect(_in(_a, find.byIcon(Icons.star)), findsNothing);

      gmail
        ..deliver(msg('b', subject: 'Arrivato altrove'))
        ..deliver(msg('a', isRead: true, isStarred: true));
      await tester.pumpAndSettle();

      expect(_in(_b, find.text('Arrivato altrove')), findsOneWidget);
      expect(_in(_a, find.byKey(const ValueKey('unread'))), findsNothing);
      expect(_in(_a, find.byIcon(Icons.star)), findsOneWidget);
      expect(gmail.initialSyncs, 1, reason: 'incremental from then on');
    },
  );

  testWidgets('without the change signal, the 60 s poll still syncs', (
    tester,
  ) async {
    await start(tester);
    gmail.dropSignal();
    await tester.pumpAndSettle();

    gmail.deliver(msg('b'));
    await tester.pumpAndSettle();
    h.clock.advance(const Duration(seconds: 59));
    await tester.pumpAndSettle();
    expect(find.byKey(_b), findsNothing);

    h.clock.advance(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(_b), findsOneWidget);
  });

  testWidgets(
    'offline shows the discreet indicator; back online, the incremental sync fetches only the differences',
    (tester) async {
      await start(tester);
      expect(find.byKey(_offline), findsNothing);

      h.connectivity.online = false;
      gmail
        ..goOffline()
        ..deliver(msg('b'));
      await tester.pumpAndSettle();
      expect(find.byKey(_offline), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.byKey(_a), findsOneWidget, reason: 'still readable');
      expect(find.byKey(_b), findsNothing);

      gmail.goOnline();
      h.connectivity.online = true;
      await tester.pumpAndSettle();
      expect(find.byKey(_offline), findsNothing);
      expect(find.byKey(_b), findsOneWidget);
      expect(gmail.initialSyncs, 1);
      expect(gmail.lastIncremental!.messages.map((m) => m.id), ['b']);
    },
  );

  testWidgets('pull-to-refresh starts a sync', (tester) async {
    await start(tester);
    gmail
      ..dropSignal()
      ..deliver(msg('b'));
    await tester.pumpAndSettle();
    expect(find.byKey(_b), findsNothing);

    await tester.fling(find.byKey(_a), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.byKey(_b), findsOneWidget);
  });

  testWidgets('coming back to the app starts a sync', (tester) async {
    await start(tester);
    gmail
      ..dropSignal()
      ..deliver(msg('b'));
    await tester.pumpAndSettle();

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(_b), findsOneWidget);
  });

  testWidgets(
    'the UI stays responsive during a slow sync: it reads only the database',
    (tester) async {
      await start(tester);
      final slow = gmail.hold = Completer<void>();
      gmail.deliver(msg('b'));
      await tester.pump();

      // The sync is stuck on the Provider; the list still renders and scrolls.
      await tester.drag(find.byKey(_a), const Offset(0, -50));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(_a), findsOneWidget);
      expect(find.byKey(_b), findsNothing);

      gmail.hold = null;
      slow.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(_b), findsOneWidget);
    },
  );
}
