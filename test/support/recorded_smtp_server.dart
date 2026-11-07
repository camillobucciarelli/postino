// An SMTP server on localhost answering with recorded replies: for what GreenMail cannot show (SIZE, a refusal).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart' show SmtpClient;
import 'package:postino/core/data/imap/password_credentials.dart';
import 'package:postino/core/domain/mail_servers.dart';
import 'package:postino/core/domain/platform_services.dart';

/// Plain TCP on 127.0.0.1: the sender reaches it through [plainSmtpConnector], never with a password over a network.
/// EHLO announces the `ehlo` lines of [start]; its `answer` replies to any other command (null: `250 ok`);
/// DATA takes the message.
class RecordedSmtpServer._(
  final ServerSocket _socket,
  final List<String> _ehlo,
  final String? Function(String command)? _answer,
) {
  /// Every line received, commands and message text, in order.
  final lines = <String>[];

  static Future<RecordedSmtpServer> start({
    List<String> ehlo = const ['AUTH PLAIN LOGIN'],
    String? Function(String command)? answer,
  }) async {
    final server = RecordedSmtpServer._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0), ehlo, answer);
    server._socket.listen(server._serve);
    return server;
  }

  Future<void> stop() => _socket.close();

  /// The commands received, without the message text.
  Iterable<String> get commands => lines.where((l) => RegExp(r'^[A-Z]{4}( |$)').hasMatch(l));

  /// Writes this server, with [password], in [keychain] as the SMTP (and IMAP) server of [accountId].
  Future<void> remember(SecureStore keychain, String accountId, {required String password}) {
    final s = MailServer(host: '127.0.0.1', port: _socket.port, security: ServerSecurity.ssl);
    return PasswordCredentials(
      password: password,
      servers: ServerSettings(imap: s, smtp: s),
    ).write(keychain, accountId);
  }

  void _serve(Socket client) {
    client.write('220 recorded ESMTP ready\r\n');
    var data = false;
    utf8.decoder.bind(client).transform(const LineSplitter()).listen((line) {
      lines.add(line);
      if (data) {
        if (line == '.') {
          data = false;
          client.write('250 queued\r\n');
        }
        return;
      }
      switch (line.split(' ').first.toUpperCase()) {
        case 'EHLO':
          final caps = ['localhost', ..._ehlo];
          for (final (i, c) in caps.indexed) {
            client.write('250${i == caps.length - 1 ? ' ' : '-'}$c\r\n');
          }
        case 'DATA':
          data = true;
          client.write('354 go ahead\r\n');
        case 'QUIT':
          client.write('221 bye\r\n');
          unawaited(client.close());
        default:
          client.write('${_answer?.call(line) ?? '250 ok'}\r\n');
      }
    }, onError: (_) {});
  }
}

/// The plain connection to a [RecordedSmtpServer], whatever the stored security says, and its EHLO.
Future<void> plainSmtpConnector(SmtpClient c, MailServer s) async {
  await c.connectToServer(s.host, s.port, isSecure: false);
  await c.ehlo();
}
