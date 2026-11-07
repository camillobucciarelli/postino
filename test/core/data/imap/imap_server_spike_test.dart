// Spike: server GreenMail e porte su TLS funzionano; un client enough_mail entra, fa LIST e consegna via SMTP.
@Tags(['imap'])
library;

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_mail_provider.dart' show msg;
import '../../../support/greenmail_server.dart';
import '../../../support/imap_harness.dart';

void main() {
  late ImapHarness h;
  setUp(() async => h = await ImapHarness.create());
  tearDown(() => h.dispose());
  tearDownAll(ImapHarness.stopServer);

  final skip = imapSkipReason;

  test('login e LIST su TLS, e le capability che il server annuncia', () async {
    final (caps, paths) = await h.withClient((c) async {
      final mailboxes = await c.listMailboxes();
      return ((await c.capability()).map((c) => c.name).toList(), mailboxes.map((m) => m.path).toList());
    });
    // Da annotare nella PR (#161): le estensioni che offre GreenMail.
    // ignore: avoid_print
    print('GreenMail $greenmailVersion CAPABILITY: ${caps.join(' ')}');
    expect(paths, contains('INBOX'));
    expect(caps, containsAll(['IDLE', 'MOVE', 'UIDPLUS']));
  }, skip: skip);

  test('un messaggio consegnato via SMTP si legge in INBOX', () async {
    final smtp = SmtpClient('postino.test', onBadCertificate: (_) => true);
    await smtp.connectToServer(GreenmailServer.host, h.server.smtpsPort);
    await smtp.ehlo();
    await smtp.authenticate(h.address, h.password);
    final message =
        (MessageBuilder.prepareMultipartAlternativeMessage(plainText: 'Ciao', htmlText: '<p>Ciao</p>')
              ..from = [MailAddress(null, GreenmailServer.addressOf('bob'))]
              ..to = [MailAddress(null, GreenmailServer.addressOf(h.login))]
              ..subject = 'Via SMTP')
            .buildMimeMessage();
    final sent = await smtp.sendMessage(message);
    await smtp.quit();
    await smtp.disconnect();
    expect(sent.isOkStatus, isTrue);

    final subjects = await h.withClient((c) async {
      await c.selectInbox();
      return (await c.fetchRecentMessages(messageCount: 5)).messages.map((m) => m.decodeSubject()).toList();
    });
    expect(subjects, ['Via SMTP']);
  }, skip: skip);

  test("le primitive dell'harness: deliver, removeRemotely, expireCursors, breakAuth", () async {
    Future<(int, int?)> inbox() => h.withClient((c) async {
      final box = await c.selectInbox();
      return (box.messagesExists, box.uidValidity);
    });

    await h.deliver(msg('a', isRead: true));
    await h.deliver(msg('b'));
    expect((await inbox()).$1, 2);
    await h.removeRemotely('a');
    final (count, validity) = await inbox();
    expect(count, 1);

    // La casella ricreata ha un UIDVALIDITY nuovo e nessuna posta.
    await Future<void>.delayed(const Duration(seconds: 1));
    await h.expireCursors();
    final after = await inbox();
    expect(after.$1, 0);
    expect(after.$2, isNot(validity));

    await h.breakAuth();
    await expectLater(h.connect(), throwsA(isA<ImapException>()));
  }, skip: skip);
}
