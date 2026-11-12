// Notifiche della posta nuova con deep link (#39): the sync notifies the new inbox messages (never at the first
// sync, never for the Conversazione on screen), and a tap opens the Conversazione over the Posta unificata.
// The cold start is in notification_cold_start_test.dart: it needs routefly's statics fresh.
import 'dart:async';

import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/mail_notification.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import '../../support/ui.dart';
import 'notification_steps.dart';

late Harness h;
late FakeMailProvider gmail;

/// Starts the app at 390×844 on the Posta unificata with Account a1, whose inbox already has message `a`.
Future<void> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  gmail = (await h.addAccount(notifiedAccount))..deliver(msg('a', subject: 'Primo'));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  // Routefly keeps the last navigation in statics.
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

List<String> _notified() => [for (final n in h.notifications.shown) n.conversation.conversationId];

void main() {
  testWidgets('the first sync notifies nothing; a new inbox message of the next one is notified', (tester) async {
    await _start(tester);
    expect(find.text('Primo'), findsOneWidget);
    expect(h.notifications.shown, isEmpty);

    gmail.deliver(msg('b', fromName: 'Ada Lovelace', subject: 'Cena', snippet: 'Venerdì?'));
    await tester.pumpAndSettle();

    expect(h.notifications.shown, [
      const MailNotification(
        conversation: (accountId: notifiedAccount, conversationId: 't-b'),
        accountAddress: '$notifiedAccount@example.com',
        sender: 'Ada Lovelace',
        subject: 'Cena',
        preview: 'Venerdì?',
      ),
    ]);
  });

  testWidgets('a change to a known message, a message outside the inbox or already read is not notified', (
    tester,
  ) async {
    await _start(tester);
    gmail
      ..deliver(msg('a', subject: 'Primo', isStarred: true))
      ..deliver(msg('s', labelIds: const [sentLabelId]))
      ..deliver(msg('r', isRead: true));
    await tester.pumpAndSettle();
    expect(h.notifications.shown, isEmpty);

    gmail.deliver(msg('c', fromName: ''));
    await tester.pumpAndSettle();
    expect(h.notifications.shown.single.sender, 'ada@example.com', reason: 'the address without a name');
  });

  testWidgets('a notification the OS refuses does not stop the next ones nor the sync', (tester) async {
    await _start(tester);
    h.notifications.failures = 1;
    gmail
      ..deliver(msg('b', subject: 'Rifiutata'), signal: false)
      ..deliver(msg('c', subject: 'Mostrata'));
    await tester.pumpAndSettle();

    expect(_notified(), ['t-c']);
    expect(find.text('Rifiutata'), findsOneWidget);
    expect(find.text('Mostrata'), findsOneWidget);
  });

  testWidgets('no notification for a message of the Conversazione on screen', (tester) async {
    await _start(tester);
    await tester.tap(find.text('Primo'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsOneWidget);

    gmail.deliver(msg('a2', conversationId: 't-a', subject: 'Re: Primo'));
    await tester.pumpAndSettle();
    expect(h.notifications.shown, isEmpty);

    gmail.deliver(msg('b', subject: 'Altro'));
    await tester.pumpAndSettle();
    expect(_notified(), ['t-b']);

    // Closed, its next message is notified again.
    await tapBack(tester);
    gmail.deliver(msg('a3', conversationId: 't-a'));
    await tester.pumpAndSettle();
    expect(_notified(), ['t-b', 't-a']);
  });

  for (final away in [AppLifecycleState.hidden, AppLifecycleState.paused]) {
    testWidgets('the Conversazione open with the app ${away.name} (tray, background) is notified', (tester) async {
      await _start(tester);
      await tester.tap(find.text('Primo'));
      await tester.pumpAndSettle();

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      if (away == AppLifecycleState.paused) tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      gmail.deliver(msg('a2', conversationId: 't-a'));
      await tester.pumpAndSettle();
      expect(_notified(), ['t-a']);

      if (away == AppLifecycleState.paused) tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      gmail.deliver(msg('a3', conversationId: 't-a'));
      await tester.pumpAndSettle();
      expect(_notified(), ['t-a'], reason: 'back in front, on screen again');
    });
  }

  testWidgets(
    'under a page pushed over it (Impostazioni) the open Conversazione is notified; a dialog does not hide it',
    (tester) async {
      await _start(tester);
      await tester.tap(find.text('Primo'));
      await tester.pumpAndSettle();

      unawaited(Routefly.push<void>(routePaths.impostazioni.path));
      await tester.pumpAndSettle();
      gmail.deliver(msg('a2', conversationId: 't-a'));
      await tester.pumpAndSettle();
      expect(_notified(), ['t-a']);

      Navigator.of(tester.element(find.byType(ConversationView, skipOffstage: false))).pop();
      await tester.pumpAndSettle();
      gmail.deliver(msg('a3', conversationId: 't-a'));
      await tester.pumpAndSettle();
      expect(_notified(), ['t-a'], reason: 'back on screen');

      unawaited(
        showDialog<void>(context: tester.element(find.byType(ConversationView)), builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      gmail.deliver(msg('a4', conversationId: 't-a'));
      await tester.pumpAndSettle();
      expect(_notified(), ['t-a'], reason: 'a dialog leaves it on screen');
    },
  );

  testWidgets(
    'a tap on a notification while the app runs opens the Conversazione; Indietro goes to the Posta unificata',
    (tester) async {
      await _start(tester);
      expectUnified();

      h.notifications.tap(const ConversationTarget((accountId: notifiedAccount, conversationId: 't-a')));
      await tester.pumpAndSettle();
      expect(tester.widget<ConversationView>(find.byType(ConversationView)).conversationId, 't-a');

      await tapBack(tester);
      expectUnified();
    },
  );

  testWidgets('tapped while another list is in front, Indietro still goes to the Posta unificata', (tester) async {
    await _start(tester);
    unawaited(Routefly.navigate(routePaths.posta.$accountId.path.changes({'accountId': notifiedAccount})));
    await tester.pumpAndSettle();
    expect(find.text('Posta unificata'), findsNothing);

    h.notifications.tap(const ConversationTarget((accountId: notifiedAccount, conversationId: 't-a')));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsOneWidget);

    await tapBack(tester);
    expectUnified();
  });

  testWidgets("the system's Indietro (Android) from a tapped notification goes to the Posta unificata", (tester) async {
    await _start(tester);
    h.notifications.tap(const ConversationTarget((accountId: notifiedAccount, conversationId: 't-a')));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expectUnified();
    expect(icon(PostinoIcons.arrowLeft), findsNothing);
  });
}
