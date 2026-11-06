// The IMAP error mapping, shared by the test connection and the adapter.

import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_failure.dart';
import 'package:postino/core/domain/result.dart';

void main() {
  final imap = ImapClient();
  final smtp = SmtpClient('localhost');

  test('a NO at the login on a live connection is a refusal of the credentials', () {
    expect(imapFailure(ImapException(imap, 'NO'), atLogin: true, connected: true), isA<AuthFailure>());
    // RFC 5530: the server is down for now, the password may be right.
    expect(
      imapFailure(ImapException(imap, 'NO [UNAVAILABLE] try later'), atLogin: true, connected: true),
      isA<OfflineFailure>(),
    );
    expect(imapFailure(SmtpException.message(smtp, '535'), atLogin: true, connected: true), isA<AuthFailure>());
  });

  test('a timeout or a lost connection, also at the login, is an unreachable server', () {
    expect(imapFailure(ImapException(imap, 'timeout'), atLogin: true, connected: true), isA<OfflineFailure>());
    expect(imapFailure(ImapException(imap, 'connection lost'), atLogin: true, connected: false), isA<OfflineFailure>());
    // STARTTLS chosen on port 993: the greeting never arrives.
    expect(imapFailure(ImapException(imap, 'no greeting'), atLogin: false, connected: false), isA<OfflineFailure>());
    for (final e in [const SocketException('x'), const TlsException('x'), TimeoutException('x')]) {
      expect(imapFailure(e, atLogin: true, connected: true), isA<OfflineFailure>());
    }
  });

  test('a protocol error after the login is unexpected', () {
    expect(imapFailure(ImapException(imap, 'BAD'), atLogin: false, connected: true), isA<UnexpectedFailure>());
  });
}
