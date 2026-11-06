import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
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
    final imap = await _imap(servers.imap, user, password);
    if (imap is Err) return imap;
    return _smtp(servers.smtp, user, password);
  }

  Future<Result<void>> _imap(MailServer s, String user, String password) async {
    final c = ImapClient(defaultResponseTimeout: _timeout, defaultWriteTimeout: _timeout);
    var atLogin = false;
    try {
      await c.connectToServer(s.host, s.port, isSecure: s.security == ServerSecurity.ssl, timeout: _timeout);
      if (s.security == ServerSecurity.starttls) await c.startTls();
      atLogin = true;
      await c.login(user, password);
      atLogin = false;
      await c.listMailboxes();
      await c.logout();
      return const Ok(null);
    } on Object catch (e) {
      return Err(testConnectionFailure(e, atLogin: atLogin, connected: c.isConnected));
    } finally {
      await _quietly(c.disconnect);
    }
  }

  Future<Result<void>> _smtp(MailServer s, String user, String password) async {
    // ponytail: a fixed EHLO name; the device's host name if a server ever refuses it.
    final c = SmtpClient('localhost');
    var atLogin = false;
    try {
      await c.connectToServer(s.host, s.port, isSecure: s.security == ServerSecurity.ssl, timeout: _timeout);
      await c.ehlo().timeout(_timeout);
      // startTls repeats the EHLO on the encrypted connection (RFC 3207 4.2).
      if (s.security == ServerSecurity.starttls) await c.startTls().timeout(_timeout);
      final mechanism = c.serverInfo.supportsAuth(AuthMechanism.plain) ? AuthMechanism.plain : AuthMechanism.login;
      atLogin = true;
      await c.authenticate(user, password, mechanism).timeout(_timeout);
      atLogin = false;
      await c.quit();
      return const Ok(null);
    } on Object catch (e) {
      return Err(testConnectionFailure(e, atLogin: atLogin, connected: c.isConnected));
    } finally {
      await _quietly(c.disconnect);
    }
  }
}

/// The Failure of [error], thrown by a test connection [atLogin] or not, with the connection still up
/// ([connected]) or not. enough_mail reports a timeout and a lost connection with the same exception as a server's
/// NO: only a protocol error at the login on a live connection is a refusal of the credentials. Never carries the
/// password: the login command is not part of any exception enough_mail throws.
@visibleForTesting
Failure testConnectionFailure(Object error, {required bool atLogin, required bool connected}) => switch (error) {
  SocketException() || TlsException() || TimeoutException() => const OfflineFailure(),
  ImapException(message: 'timeout') => const OfflineFailure(),
  ImapException() || SmtpException() when !connected => const OfflineFailure(),
  ImapException() || SmtpException() when atLogin => const AuthFailure(),
  _ => UnexpectedFailure(error),
};

Future<void> _quietly(Future<void> Function() close) async {
  try {
    await close();
  } on Object {
    // Already closed or never opened: nothing to release.
  }
}
