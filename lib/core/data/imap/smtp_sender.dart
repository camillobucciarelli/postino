import 'dart:async';
import 'dart:convert';
import 'dart:io' show X509Certificate;

import 'package:enough_mail/enough_mail.dart';

import '../../domain/mail_servers.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import 'imap_failure.dart';
import 'imap_session.dart';
import 'password_credentials.dart';

/// How a client reaches [server] and greets it (EHLO); tests swap it for a plain socket to a recorded server.
typedef SmtpConnector = Future<void> Function(SmtpClient client, MailServer server);

/// TLS from the first byte, or a plain connection upgraded with STARTTLS: never the password in clear.
Future<void> connectSmtp(SmtpClient client, MailServer server) async {
  await client.connectToServer(
    server.host,
    server.port,
    isSecure: server.security == ServerSecurity.ssl,
    timeout: ImapSession.timeout,
  );
  await client.ehlo().timeout(ImapSession.timeout);
  // startTls repeats the EHLO on the encrypted connection (RFC 3207 4.2).
  if (server.security == ServerSecurity.starttls) await client.startTls().timeout(ImapSession.timeout);
}

/// One SMTP submission with the Account's saved servers and password (#162), a connection per message.
/// Never logs: enough_mail's log would print the AUTH command, the password inside.
class SmtpSender(
  final String _accountId,

  /// The user name: the Account's address.
  final String _user,
  final SecureStore _keychain, {
  final SmtpConnector _connect = connectSmtp,
  final bool Function(X509Certificate)? _onBadCertificate,
}) {
  /// Submits [raw] (rendered by `renderMime`) to its To, Cc and Bcc, without the Bcc header.
  /// Over the server's `SIZE` it is [SizeLimitFailure] before anything is sent; a 5xx answer is [RejectedFailure].
  /// [onAccepted] runs as soon as the server accepted the message, before QUIT (which may take seconds) and the
  /// disconnection: it must not throw.
  Future<void> send(String raw, {Future<void> Function()? onAccepted}) async {
    final credentials = await PasswordCredentials.read(_keychain, _accountId);
    if (credentials == null) throw const ImapFailed(AuthFailure(reason: 'no password here'));
    final mime = MimeMessage.parseFromText(raw);
    final from = mime.from?.firstOrNull ?? MailAddress(null, _user);
    final recipients = [...?mime.to, ...?mime.cc, ...?mime.bcc];
    final text = withoutBcc(raw);
    // ponytail: a fixed EHLO name, as the test connection; the device's host name if a server ever refuses it.
    final c = SmtpClient('localhost', onBadCertificate: _onBadCertificate);
    var atLogin = false;
    try {
      await _connect(c, credentials.servers.smtp);
      if (c.serverInfo.maxMessageSize case final max? when max > 0 && utf8.encode(text).length > max) {
        throw ImapFailed(SizeLimitFailure(max));
      }
      final mechanism = c.serverInfo.supportsAuth(AuthMechanism.plain) ? AuthMechanism.plain : AuthMechanism.login;
      atLogin = true;
      await c.authenticate(_user, credentials.password, mechanism).timeout(ImapSession.timeout);
      atLogin = false;
      await c.sendMessageText(text, from, recipients).timeout(ImapSession.timeout);
      await onAccepted?.call();
      // Sent: a server slow to answer QUIT must not hold the Account's queue.
      await _quietly(() => c.quit().timeout(const Duration(seconds: 10)));
    } on ImapFailed {
      rethrow;
    } on SmtpException catch (e) {
      // Refused for good (a recipient, the size, the sender): retrying cannot help. A 4xx is retried.
      if (!atLogin && c.isConnected && (e.response.code ?? 0) >= 500) {
        throw ImapFailed(RejectedFailure(e.response.errorMessage));
      }
      throw ImapFailed(imapFailure(e, atLogin: atLogin, connected: c.isConnected));
    } on Object catch (e) {
      throw ImapFailed(imapFailure(e, atLogin: atLogin, connected: c.isConnected));
    } finally {
      await _quietly(c.disconnect);
    }
  }
}

/// [raw] without its `Bcc` header, folded lines included: the recipients must not see it (RFC 5322 §3.6.3).
String withoutBcc(String raw) {
  final end = raw.indexOf('\r\n\r\n');
  final head = end < 0 ? raw : raw.substring(0, end);
  final kept = <String>[];
  var skipping = false;
  for (final l in head.split('\r\n')) {
    if (!l.startsWith(' ') && !l.startsWith('\t')) skipping = l.toLowerCase().startsWith('bcc:');
    if (!skipping) kept.add(l);
  }
  return end < 0 ? kept.join('\r\n') : '${kept.join('\r\n')}${raw.substring(end)}';
}

Future<void> _quietly(Future<Object?> Function() close) async {
  try {
    await close();
  } on Object {
    // Already closed or never opened: nothing to release.
  }
}
