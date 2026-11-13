// The search on an IMAP Account (#208) in the app, against GreenMail: what is only in Archivio, older than the sync
// window, is found after Invio and opens as a whole Conversazione.
@Tags(['imap'])
library;

import 'dart:async';
import 'dart:convert' show utf8;

import 'package:enough_mail/enough_mail.dart' show DateCodec;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/greenmail_server.dart';
import '../../support/harness.dart';
import '../../support/imap_harness.dart';

String _raw(String id, String subject, DateTime date, {String? references}) =>
    'Message-ID: <$id@example.com>\r\n'
    'From: Ada <ada@example.com>\r\n'
    'To: me@example.com\r\n'
    'Subject: $subject\r\n'
    'Date: ${DateCodec.encodeDate(date)}\r\n'
    '${references == null ? '' : 'References: <$references@example.com>\r\n'}'
    'Content-Type: text/plain; charset=utf-8\r\n\r\ncontratto\r\n';

/// Real pauses for the server to answer, with a little fake time each (enough_mail's commands wait on timers), until
/// [done] or [seconds] of real time. Stays well under the 15 s the search may take.
Future<void> _settle(WidgetTester tester, bool Function() done, int seconds) async {
  for (var i = 0; i < seconds * 20 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  if (imapSkipReason case final reason?) {
    test('IMAP search in the app', () {}, skip: reason);
    return;
  }
  tearDownAll(ImapHarness.stopServer);

  testWidgets('a message only in Archivio, older than the sync window, is found and opens whole', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await Harness.create();
    final imap = (await tester.runAsync(ImapHarness.create))!;
    addTearDown(imap.dispose);
    final old = DateTime.now().subtract(const Duration(days: 200));
    await tester.runAsync(() async {
      await imap.appendBytes('Archive', utf8.encode(_raw('old', 'Contratto di affitto', old)), at: old);
      await imap.appendBytes(
        'Archive',
        utf8.encode(_raw('reply', 'Re: Contratto di affitto', old.add(const Duration(days: 1)), references: 'old')),
        at: old.add(const Duration(days: 1)),
      );
    });
    getIt.registerSingleton<MailProvider>(imap.provider, instanceName: imap.accountId);
    await getIt<MailStore>().addAccount(
      Account(id: imap.accountId, address: imap.address, provider: ProviderKind.icloud, color: 0, position: 0),
    );
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    unawaited(Routefly.navigate(routePaths.posta.path));
    await tester.pumpAndSettle();
    await _settle(tester, () => false, 3);
    await tester.tap(find.byTooltip('Cerca'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'affitto');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    final row = find.textContaining('Re: Contratto di affitto');
    expect(row, findsNothing, reason: 'while typing only the local search');

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _settle(tester, () => row.evaluate().isNotEmpty, 8);
    await tester.pumpAndSettle();
    expect(row, findsWidgets, reason: 'one row for the Conversazione, its newest message');

    await tester.tap(row.first);
    await _settle(tester, () => find.byType(ConversationView).evaluate().isNotEmpty, 8);
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsOneWidget);
    expect(find.text('Contratto di affitto'), findsWidgets);
    expect(find.text('Re: Contratto di affitto'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsNothing);

    // The connections' timers (enough_mail's) end with them.
    await tester.runAsync(imap.provider.close);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
  });
}
