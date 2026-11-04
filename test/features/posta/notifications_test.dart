// Notifiche della posta nuova con deep link (#39): the sync notifies the new inbox messages (never at the first
// sync, never for the open Conversazione), and a tap opens the Conversazione over the Posta unificata.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/mail_notification.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import '../../support/ui.dart';

const _id = 'a1';

late Harness h;
late FakeMailProvider gmail;

/// Starts the app at 390×844 with Account a1, whose inbox already has message `a` (the first sync).
Future<void> _start(WidgetTester tester, {ConversationKey? launch}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  gmail = (await h.addAccount(_id))..deliver(msg('a', subject: 'Primo'));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: PostinoApp(launch: launch)));
  await tester.pumpAndSettle();
}

/// The Posta unificata is in front, with no Conversazione open.
void _expectUnified() {
  expect(Routefly.currentUri.path, routePaths.posta.path);
  expect(find.byType(ConversationView), findsNothing);
  expect(find.text('Posta unificata'), findsOneWidget);
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(icon(PostinoIcons.arrowLeft));
  await tester.pumpAndSettle();
}

void main() {
  // First: routefly keeps the last navigation in statics, and this start must not be moved by it.
  testWidgets('launched by a tap on a notification, the Conversazione opens; Indietro goes to the Posta unificata', (
    tester,
  ) async {
    await _start(tester, launch: (accountId: _id, conversationId: 't-a'));

    expect(tester.widget<ConversationView>(find.byType(ConversationView)).conversationId, 't-a');
    await _back(tester);
    _expectUnified();
  });

  testWidgets('the first sync notifies nothing; a new inbox message of the next one is notified', (tester) async {
    await _start(tester);
    unawaited(Routefly.navigate(routePaths.posta.path));
    await tester.pumpAndSettle();
    expect(find.text('Primo'), findsOneWidget);
    expect(h.notifications.shown, isEmpty);

    gmail.deliver(msg('b', fromName: 'Ada Lovelace', subject: 'Cena', snippet: 'Venerdì?'));
    await tester.pumpAndSettle();

    expect(h.notifications.shown, [
      const MailNotification(
        conversation: (accountId: _id, conversationId: 't-b'),
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

  testWidgets('no notification for a message of the Conversazione on screen', (tester) async {
    await _start(tester);
    unawaited(Routefly.navigate(routePaths.posta.path));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Primo'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsOneWidget);

    gmail.deliver(msg('a2', conversationId: 't-a', subject: 'Re: Primo'));
    await tester.pumpAndSettle();
    expect(h.notifications.shown, isEmpty);

    gmail.deliver(msg('b', subject: 'Altro'));
    await tester.pumpAndSettle();
    expect(h.notifications.shown.map((n) => n.conversation.conversationId), ['t-b']);

    // Closed, its next message is notified again.
    await _back(tester);
    gmail.deliver(msg('a3', conversationId: 't-a'));
    await tester.pumpAndSettle();
    expect(h.notifications.shown.map((n) => n.conversation.conversationId), ['t-b', 't-a']);
  });

  testWidgets(
    'a tap on a notification while the app runs opens the Conversazione; Indietro goes to the Posta unificata',
    (tester) async {
      await _start(tester);
      unawaited(Routefly.navigate(routePaths.posta.path));
      await tester.pumpAndSettle();
      _expectUnified();

      h.notifications.tap((accountId: _id, conversationId: 't-a'));
      await tester.pumpAndSettle();
      expect(tester.widget<ConversationView>(find.byType(ConversationView)).conversationId, 't-a');

      await _back(tester);
      _expectUnified();
    },
  );
}
