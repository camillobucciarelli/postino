// An IMAP server on localhost answering with recorded responses: for what GreenMail cannot show (CONDSTORE,
// QRESYNC, no IDLE, a refused login after the greeting).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart' show ImapClient;
import 'package:postino/core/data/imap/password_credentials.dart';
import 'package:postino/core/domain/mail_servers.dart';
import 'package:postino/core/domain/platform_services.dart';

/// What the server answers to [command] (the line without its tag): untagged lines (`* ...`), then, if the last
/// line is a status (`OK`, `NO`, `BAD`), it goes out tagged; otherwise a tagged `OK` closes the answer.
typedef ImapScript = List<String> Function(String command);

/// What [ImapScript] returns for a command the server never answers (a slow SEARCH): the client times out.
const hang = ['<hang>'];

/// Plain TCP on 127.0.0.1: the adapter reaches it through [plainConnector], never with a password over a network.
class RecordedImapServer._(final ServerSocket _socket, final ImapScript _script) {
  /// Every command received, without its tag, in order.
  final commands = <String>[];

  int get port => _socket.port;

  static Future<RecordedImapServer> start(ImapScript script) async {
    final server = RecordedImapServer._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0), script);
    server._socket.listen(server._serve);
    return server;
  }

  Future<void> stop() => _socket.close();

  /// Writes this server, with [password], in [keychain] as the IMAP server of [accountId].
  Future<void> remember(SecureStore keychain, String accountId, {String password = 'recorded'}) {
    final s = MailServer(host: '127.0.0.1', port: port, security: ServerSecurity.ssl);
    return PasswordCredentials(
      password: password,
      servers: ServerSettings(imap: s, smtp: s),
    ).write(keychain, accountId);
  }

  void _serve(Socket client) {
    client.write('* OK [CAPABILITY IMAP4rev1] recorded server ready\r\n');
    utf8.decoder.bind(client).transform(const LineSplitter()).listen((line) {
      final space = line.indexOf(' ');
      if (space < 0) return; // DONE after IDLE, and the like
      final tag = line.substring(0, space);
      final command = line.substring(space + 1);
      commands.add(command);
      final answer = [..._script(command)];
      if (answer.length == 1 && answer.first == hang.first) return;
      final status = answer.isNotEmpty && RegExp('^(OK|NO|BAD)( |\$)').hasMatch(answer.last)
          ? answer.removeLast()
          : 'OK done';
      for (final l in answer) {
        client.write('$l\r\n');
      }
      client.write('$tag $status\r\n');
      if (command.toUpperCase() == 'LOGOUT') unawaited(client.close());
    }, onError: (_) {});
  }
}

/// The plain connection to a [RecordedImapServer], whatever the stored security says.
Future<void> plainConnector(ImapClient c, MailServer s) => c.connectToServer(s.host, s.port, isSecure: false);

/// A FETCH literal: `{length}` CRLF and the bytes.
String literal(String text) => '{${utf8.encode(text).length}}\r\n$text';

/// The common answers: LOGIN, CAPABILITY with [capabilities], ENABLE, LIST of [folders] (flags, path), LOGOUT;
/// null for any other command.
List<String>? basics(
  String command, {
  required String capabilities,
  List<(String, String)> folders = const [('', 'INBOX')],
}) {
  final verb = command.split(' ').first.toUpperCase();
  return switch (verb) {
    'LOGIN' => ['OK LOGIN completed'],
    'CAPABILITY' => ['* CAPABILITY $capabilities'],
    'ENABLE' => ['* ENABLED ${command.substring(7)}'],
    'LIST' => [for (final (flags, path) in folders) '* LIST ($flags) "/" "$path"'],
    'LOGOUT' => ['* BYE'],
    'NOOP' => <String>[],
    _ => null,
  };
}
