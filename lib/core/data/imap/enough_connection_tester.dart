import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:injectable/injectable.dart';

import '../../domain/connection_tester.dart';
import '../../domain/mail_servers.dart';
import '../../domain/result.dart';

/// The test connection with enough_mail: IMAP login + LIST, then SMTP EHLO + AUTH, each closed at once.
@LazySingleton(as: ConnectionTester, env: [Environment.prod])
class EnoughConnectionTester() implements ConnectionTester {
  /// A step that hangs past this is an unreachable server.
  static const _timeout = Duration(seconds: 30);

  @override
  Future<Result<void>> test(ServerSettings servers, {required String user, required String password}) async {
    final imap = await _run(() => _imap(servers.imap, user, password));
    if (imap is Err) return imap;
    return _run(() => _smtp(servers.smtp, user, password));
  }

  Future<void> _imap(MailServer s, String user, String password) async {
    final c = ImapClient(defaultResponseTimeout: _timeout, defaultWriteTimeout: _timeout);
    try {
      await c.connectToServer(s.host, s.port, isSecure: s.security == ServerSecurity.ssl, timeout: _timeout);
      if (s.security == ServerSecurity.starttls) await c.startTls();
      await _login(() => c.login(user, password));
      await c.listMailboxes();
      await c.logout();
    } finally {
      await _quietly(c.disconnect);
    }
  }

  Future<void> _smtp(MailServer s, String user, String password) async {
    // ponytail: a fixed EHLO name; the device's host name if a server ever refuses it.
    final c = SmtpClient('localhost');
    try {
      await c.connectToServer(s.host, s.port, isSecure: s.security == ServerSecurity.ssl, timeout: _timeout);
      await c.ehlo().timeout(_timeout);
      // startTls repeats the EHLO on the encrypted connection (RFC 3207 4.2).
      if (s.security == ServerSecurity.starttls) await c.startTls().timeout(_timeout);
      final mechanism = c.serverInfo.supportsAuth(AuthMechanism.plain) ? AuthMechanism.plain : AuthMechanism.login;
      await _login(() => c.authenticate(user, password, mechanism).timeout(_timeout));
      await c.quit();
    } finally {
      await _quietly(c.disconnect);
    }
  }
}

/// The server refused the credentials at the login step.
final class _Refused() implements Exception {}

/// Runs a login; a protocol error there is the server's refusal of the credentials.
Future<void> _login(Future<Object?> Function() login) async {
  try {
    await login();
  } on ImapException {
    throw _Refused();
  } on SmtpException {
    throw _Refused();
  }
}

Future<Result<void>> _run(Future<void> Function() step) async {
  try {
    await step();
    return const Ok(null);
  } on Object catch (e) {
    return Err(_failure(e));
  }
}

/// The Failure of an error thrown by a test connection. Never carries the password: the login command is not part
/// of any exception enough_mail throws.
Failure _failure(Object error) => switch (error) {
  _Refused() => const AuthFailure(),
  SocketException() || TlsException() || TimeoutException() => const OfflineFailure(),
  _ => UnexpectedFailure(error),
};

Future<void> _quietly(Future<void> Function() close) async {
  try {
    await close();
  } on Object {
    // Already closed or never opened: nothing to release.
  }
}
