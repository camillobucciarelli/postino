// SMTP submission (#166) against a recorded server: SIZE, Bcc, refusals, and the password never logged.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_failure.dart';
import 'package:postino/core/data/imap/smtp_sender.dart';
import 'package:postino/core/data/mime.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_platform.dart';
import '../../../support/recorded_smtp_server.dart';

const _id = 'imap:ada@example.com';
const _user = 'ada@example.com';
// Not a real credential: the recorded server accepts anything.
const _password = 'recorded-app-password';

final _raw = renderMime(
  const OutgoingMessage(
    messageId: '<s1@example.com>',
    from: 'Ada <ada@example.com>',
    to: ['bruno@example.com'],
    cc: ['carla@example.com'],
    bcc: ['dario@example.com'],
    subject: 'Ciao',
    body: '<p>Ciao Bruno</p>',
  ),
  DateTime.utc(2026),
);

Matcher _fails<F>() => throwsA(isA<ImapFailed>().having((e) => e.failure, 'failure', isA<F>()));

void main() {
  late RecordedSmtpServer server;
  late SmtpSender sender;

  Future<void> start({List<String> ehlo = const ['AUTH PLAIN LOGIN'], String? Function(String)? answer}) async {
    server = await RecordedSmtpServer.start(ehlo: ehlo, answer: answer);
    final keychain = FakeSecureStore();
    await server.remember(keychain, _id, password: _password);
    sender = SmtpSender(_id, _user, keychain, connect: plainSmtpConnector);
  }

  tearDown(() => server.stop());

  test('onAccepted runs after the message is accepted and before QUIT (#175)', () async {
    await start();
    List<String>? seen;
    await sender.send(_raw, onAccepted: () async => seen = List.of(server.commands));
    expect(seen!.map((c) => c.split(' ').first), contains('DATA'));
    expect(seen!.map((c) => c.split(' ').first), isNot(contains('QUIT')));
  });

  test('onAccepted does not run when the server refuses the message (#175)', () async {
    await start(answer: (c) => c.startsWith('RCPT') ? '550 no' : null);
    var ran = false;
    await expectLater(sender.send(_raw, onAccepted: () async => ran = true), _fails<RejectedFailure>());
    expect(ran, isFalse);
  });

  test('submits to To, Cc and Bcc, without the Bcc header, after AUTH', () async {
    await start();
    await sender.send(_raw);
    expect(server.commands.map((c) => c.split(' ').first), [
      'EHLO',
      'AUTH',
      'MAIL',
      'RCPT',
      'RCPT',
      'RCPT',
      'DATA',
      'QUIT',
    ]);
    expect(server.commands.where((c) => c.startsWith('RCPT')), [
      'RCPT TO:<bruno@example.com>',
      'RCPT TO:<carla@example.com>',
      'RCPT TO:<dario@example.com>',
    ]);
    expect(server.lines.where((l) => l.toLowerCase().startsWith('bcc:')), isEmpty);
    expect(server.lines, contains('Message-Id: <s1@example.com>'));
  });

  test('over the SIZE the server announces: SizeLimitFailure before AUTH and MAIL', () async {
    await start(ehlo: const ['SIZE 100', 'AUTH PLAIN LOGIN']);
    await expectLater(
      sender.send(_raw),
      throwsA(
        isA<ImapFailed>().having(
          (e) => e.failure,
          'failure',
          isA<SizeLimitFailure>().having((f) => f.limitBytes, 'limitBytes', 100),
        ),
      ),
    );
    expect(server.commands.map((c) => c.split(' ').first), ['EHLO']);
  });

  test('a recipient refused (5xx) is RejectedFailure; a 4xx is retried later', () async {
    await start(answer: (c) => c.startsWith('RCPT') ? '550 5.1.1 no such user' : null);
    await expectLater(sender.send(_raw), _fails<RejectedFailure>());
    await server.stop();
    await start(answer: (c) => c.startsWith('RCPT') ? '500 5.5.1 syntax' : null);
    await expectLater(sender.send(_raw), _fails<RejectedFailure>(), reason: '500 is the lowest permanent code');
    await server.stop();
    await start(answer: (c) => c.startsWith('MAIL') ? '451 4.3.0 try later' : null);
    await expectLater(sender.send(_raw), _fails<UnexpectedFailure>());
  });

  test('a refused AUTH is AuthFailure', () async {
    await start(answer: (c) => c.startsWith('AUTH') ? '535 5.7.8 bad credentials' : null);
    await expectLater(sender.send(_raw), _fails<AuthFailure>());
  });

  test('the password never reaches the log', () async {
    await start(answer: (c) => c.startsWith('RCPT TO:<dario') ? '550 5.1.1 no such user' : null);
    final printed = <String>[];
    final debug = debugPrint;
    debugPrint = (m, {wrapWidth}) => printed.add(m ?? '');
    try {
      await runZoned(() async {
        await expectLater(sender.send(_raw), _fails<RejectedFailure>());
      }, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => printed.add(line)));
    } finally {
      debugPrint = debug;
    }
    // The password went to the server, inside AUTH PLAIN, and nowhere else.
    final plain = server.commands.singleWhere((c) => c.startsWith('AUTH PLAIN ')).substring(11);
    expect(utf8.decode(base64.decode(plain)), endsWith('\u0000$_password'));
    expect(printed.where((l) => l.contains(_password) || l.contains(plain)), isEmpty);
  });

  test('withoutBcc drops the header and its folded lines only', () {
    expect(
      withoutBcc('From: a\r\nBcc: b@example.com,\r\n c@example.com\r\nTo: d\r\n\r\nBcc: in the body\r\n'),
      'From: a\r\nTo: d\r\n\r\nBcc: in the body\r\n',
    );
  });
}
