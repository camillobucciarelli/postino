// fetchConversation of the IMAP adapter on GreenMail (#164), beyond the contract.
@Tags(['imap'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_provider.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_mail_provider.dart' show msg;
import '../../../support/fake_platform.dart';
import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/greenmail_server.dart';
import '../../../support/imap_harness.dart';

void main() {
  if (imapSkipReason case final reason?) {
    test('IMAP Conversazioni', () {}, skip: reason);
    return;
  }
  late ImapHarness h;
  setUp(() async => h = await ImapHarness.create());
  tearDown(() => h.dispose());
  tearDownAll(ImapHarness.stopServer);

  test('a reply in Inviati older than the sync window is found, the message itself too', () async {
    final now = DateTime.now().toUtc();
    await h.deliver(msg('root', date: now.subtract(const Duration(days: 200))));
    await h.deliver(
      msg(
        'reply',
        labelIds: const ['SENT'],
        from: h.address,
        to: const ['ada@example.com'],
        date: now.subtract(const Duration(days: 199)),
        references: const ['<root@example.com>'],
      ),
    );
    await h.deliver(msg('other'));
    // A clock far ahead: the INTERNALDATE of all three is out of the 90 days, as if they had come long ago.
    final later = ImapProvider(
      h.accountId,
      h.address,
      h.keychain,
      FakeClock(now.add(const Duration(days: 200))),
      onBadCertificate: (_) => true,
    );
    addTearDown(later.close);
    expect(okValue(await later.initialSync()).messages, isEmpty);
    final messages = okValue(await later.fetchConversation('<root@example.com>'));
    expect(messages.map((m) => m.id), unorderedEquals([h.idOf('root'), h.idOf('reply')]));
    expect(messages.map((m) => m.conversationId).toSet(), {'<root@example.com>'});
    expect(messages.map((m) => m.snippet).toSet(), {'Ciao'});
    expect(messages.singleWhere((m) => m.id == h.idOf('reply')).labelIds, ['SENT']);
  });

  test('a chain of replies that cite only their parent is found whole', () async {
    await h.deliver(msg('a'));
    await h.append(
      'Sent',
      'From: ${h.address}\r\nTo: ada@example.com\r\nSubject: Re: Oggetto\r\nMessage-ID: <b@example.com>\r\n'
          'In-Reply-To: <a@example.com>\r\n\r\nOk\r\n',
    );
    await h.append(
      'INBOX',
      'From: ada@example.com\r\nTo: ${h.address}\r\nSubject: Re: Oggetto\r\nMessage-ID: <c@example.com>\r\n'
          'In-Reply-To: <b@example.com>\r\n\r\nGrazie\r\n',
    );
    final messages = okValue(await h.provider.fetchConversation('<a@example.com>'));
    expect(
      messages.map((m) => m.messageId),
      unorderedEquals(['<a@example.com>', '<b@example.com>', '<c@example.com>']),
    );
  });

  test('a message without Message-ID is its own Conversazione, fetched by its Provider id', () async {
    await h.append('INBOX', 'From: ada@example.com\r\nTo: ${h.address}\r\nSubject: Senza id\r\n\r\nCiao\r\n');
    final m = okValue(await h.provider.initialSync()).messages.single;
    expect(m.messageId, isEmpty);
    final messages = okValue(await h.provider.fetchConversation(m.conversationId));
    expect(messages.map((x) => x.id), [m.id]);
  });

  test('a Conversazione with no message is NotFound', () async {
    expect(await h.provider.fetchConversation('<nessuno@example.com>'), isErr<NotFoundFailure>());
  });
}
