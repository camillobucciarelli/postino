// Sending on IMAP (#166) against GreenMail: SMTP delivers, Inviati keeps one copy across retries, and a failed
// APPEND is retried without a second submission.
@Tags(['imap'])
library;

import 'dart:io' show SocketException;

import 'package:enough_mail/enough_mail.dart' show SmtpClient;
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_provider.dart';
import 'package:postino/core/data/imap/imap_session.dart';
import 'package:postino/core/data/imap/smtp_sender.dart';
import 'package:postino/core/data/mime.dart';
import 'package:postino/core/domain/mail_servers.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';
import '../../../support/greenmail_server.dart';
import '../../../support/imap_harness.dart';

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got $failure'),
};

Matcher _err<F>() => isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<F>());

OutgoingMessage _draft({String to = 'b@example.com', String subject = 's', String body = '<p>Ciao</p>'}) =>
    OutgoingMessage(messageId: '<x@example.com>', from: 'me@example.com', to: [to], subject: subject, body: body);

void main() {
  if (imapSkipReason case final reason?) {
    test('IMAP send and Bozze', () {}, skip: reason);
    return;
  }
  tearDownAll(ImapHarness.stopServer);

  late ImapHarness h;
  setUp(() async => h = await ImapHarness.create());
  tearDown(() => h.dispose());

  /// Another adapter of the same Account (its memory empty, as after a restart), with the given connectors.
  ImapProvider adapter({
    ImapConnector connect = connectImap,
    SmtpConnector smtp = connectSmtp,
    bool appendToSent = true,
  }) => ImapProvider(
    h.accountId,
    h.address,
    h.keychain,
    FakeClock(DateTime.now().toUtc()),
    connect: connect,
    smtpConnect: smtp,
    appendToSent: appendToSent,
    onBadCertificate: (_) => true,
  );

  /// How many messages with Message-ID `<x@example.com>` [path] holds (a missing folder holds none).
  Future<int> copies(String path) => h.copies(path, '<x@example.com>');

  /// GreenMail delivers right after the SMTP answer, not always before it.
  Future<int> delivered() async {
    for (var i = 0; i < 20 && await copies('INBOX') == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return copies('INBOX');
  }

  group('send', () {
    test('SMTP delivers it and Inviati holds one copy, read', () async {
      final d = _draft(to: h.address);
      final id = _ok(await h.provider.send(d.messageId, renderMime(d, DateTime.utc(2026))));
      expect(await delivered(), 1);
      expect(await copies('Sent'), 1);
      final sent = _ok(await h.provider.initialSync()).messages.where((m) => m.id == id).single;
      expect(sent.labelIds, [sentLabelId]);
      expect(sent.isRead, isTrue);
    });

    test('a retry after a lost answer finds it in Inviati: no second submission', () async {
      final d = _draft(to: h.address);
      final raw = renderMime(d, DateTime.utc(2026));
      final first = _ok(await h.provider.send(d.messageId, raw));
      var submissions = 0;
      final again = adapter(
        smtp: (SmtpClient c, MailServer s) {
          submissions++;
          return connectSmtp(c, s);
        },
      );
      addTearDown(again.close);
      expect(_ok(await again.send(d.messageId, raw)), first);
      expect(submissions, 0);
      expect(await delivered(), 1);
      expect(await copies('Sent'), 1);
    });

    test('a failed APPEND to Inviati is retried without a new SMTP submission', () async {
      final d = _draft(to: h.address);
      final raw = renderMime(d, DateTime.utc(2026));
      var imapDown = false;
      var submissions = 0;
      late ImapProvider p;
      p = adapter(
        connect: (c, s) async {
          if (imapDown) throw const SocketException('down');
          await connectImap(c, s);
        },
        smtp: (c, s) async {
          submissions++;
          // The IMAP connection drops while SMTP submits: the APPEND after it fails.
          await p.close();
          imapDown = true;
          await connectSmtp(c, s);
        },
      );
      addTearDown(p.close);
      expect(await p.send(d.messageId, raw), _err<OfflineFailure>());
      expect(await copies('Sent'), 0);
      imapDown = false;
      _ok(await p.send(d.messageId, raw));
      expect(submissions, 1);
      expect(await delivered(), 1);
      expect(await copies('Sent'), 1);
    });

    test('submitted: no SMTP connection, only the APPEND, then the Bozza goes (#175)', () async {
      final d = _draft(to: h.address);
      final raw = renderMime(d, DateTime.utc(2026));
      var submissions = 0;
      final p = adapter(
        smtp: (c, s) {
          submissions++;
          return connectSmtp(c, s);
        },
      );
      addTearDown(p.close);
      _ok(await p.send(d.messageId, raw, submitted: true));
      expect(submissions, 0);
      expect(await copies('Sent'), 1);
    });

    test(
      'a crash between SMTP and APPEND: a new adapter told submitted leaves one delivery and one copy (#175)',
      () async {
        final d = _draft(to: h.address);
        final raw = renderMime(d, DateTime.utc(2026));
        var recorded = false;
        // IMAP drops while SMTP submits: the APPEND fails (as if the process died there), the row remembers the submission.
        var imapDown = false;
        late ImapProvider first;
        first = adapter(
          connect: (c, s) async {
            if (imapDown) throw const SocketException('down');
            await connectImap(c, s);
          },
          smtp: (c, s) async {
            await first.close();
            imapDown = true;
            await connectSmtp(c, s);
          },
        );
        addTearDown(first.close);
        expect(await first.send(d.messageId, raw, onSubmitted: () async => recorded = true), _err<OfflineFailure>());
        expect(recorded, isTrue);
        expect(await copies('Sent'), 0);

        var submissions = 0;
        final second = adapter(
          smtp: (c, s) {
            submissions++;
            return connectSmtp(c, s);
          },
        );
        addTearDown(second.close);
        _ok(await second.send(d.messageId, raw, submitted: recorded));
        expect(submissions, 0);
        expect(await delivered(), 1);
        expect(await copies('Sent'), 1);
      },
    );

    test('onSubmitted failing does not stop the APPEND, nor lets the same adapter submit again (#175)', () async {
      final d = _draft(to: h.address);
      final raw = renderMime(d, DateTime.utc(2026));
      _ok(await h.provider.send(d.messageId, raw, onSubmitted: () async => throw StateError('db locked')));
      expect(await delivered(), 1);
      expect(await copies('Sent'), 1);
    });

    test('a Provider filing the submission itself: no second copy in Inviati', () async {
      final d = _draft(to: h.address);
      final raw = renderMime(d, DateTime.utc(2026));
      final p = adapter(
        smtp: (c, s) async {
          await connectSmtp(c, s);
          // As iCloud might: the submission lands in Inviati on its own.
          await h.append('Sent', raw);
        },
      );
      addTearDown(p.close);
      _ok(await p.send(d.messageId, raw));
      expect(await copies('Sent'), 1);
    });

    test('appendToSent false: no APPEND, the Message-ID stands in while the Provider has not filed it', () async {
      final d = _draft(to: h.address);
      final raw = renderMime(d, DateTime.utc(2026));
      final p = adapter(appendToSent: false);
      addTearDown(p.close);
      expect(_ok(await p.send(d.messageId, raw)), d.messageId);
      expect(await copies('Sent'), 0);
      expect(await delivered(), 1);
    });
  });
}
