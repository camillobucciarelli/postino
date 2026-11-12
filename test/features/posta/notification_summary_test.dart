// The summary «N nuovi messaggi» (#210): more than 10 new messages in a sync notify the Account once, and a tap opens
// its inbox; the system's Indietro (Android) goes from there to the Posta unificata.
import 'dart:async';

import 'package:flutter/material.dart' show Drawer;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/new_mail_summary.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import '../../support/ui.dart';
import 'notification_steps.dart';

late Harness h;
late FakeMailProvider gmail;

/// The Posta unificata at 390×844 with Account a1, whose inbox already has message `a`.
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

void main() {
  testWidgets('12 new messages in one sync: one summary of the Account, no single notification', (tester) async {
    await _start(tester);
    for (var i = 0; i < 12; i++) {
      gmail.deliver(msg('n$i'), signal: i == 11);
    }
    await tester.pumpAndSettle();

    expect(h.notifications.shown, isEmpty);
    expect(h.notifications.summaries, [
      const NewMailSummary(accountId: notifiedAccount, accountAddress: '$notifiedAccount@example.com', count: 12),
    ]);
  });

  test('the text of the summary, with its plural', () {
    LocaleSettings.setLocaleSync(AppLocale.it);
    expect(t.notifiche.newMessages(n: 11), '11 nuovi messaggi');
    expect(t.notifiche.newMessages(n: 1), '1 nuovo messaggio');
    LocaleSettings.setLocaleSync(AppLocale.en);
    expect(t.notifiche.newMessages(n: 11), '11 new messages');
  });

  testWidgets("a tap on the summary opens the Account's inbox; the system's Indietro goes to the Posta unificata", (
    tester,
  ) async {
    await _start(tester);
    h.notifications.tap(const AccountTarget(notifiedAccount));
    await tester.pumpAndSettle();
    expect(Routefly.currentUri.path, routePaths.posta.$accountId.path.changes({'accountId': notifiedAccount}));
    expect(find.text('Posta in arrivo'), findsOneWidget);
    expect(find.text('Primo'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expectUnified();
  });

  testWidgets("with the drawer open, the system's Indietro closes it first, then goes to the Posta unificata", (
    tester,
  ) async {
    await _start(tester);
    h.notifications.tap(const AccountTarget(notifiedAccount));
    await tester.pumpAndSettle();
    final inbox = routePaths.posta.$accountId.path.changes({'accountId': notifiedAccount});

    await openDrawer(tester);
    expect(find.byType(Drawer), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(Routefly.currentUri.path, inbox);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expectUnified();
  });
}
