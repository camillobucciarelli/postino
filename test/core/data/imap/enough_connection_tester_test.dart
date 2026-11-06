// The test connection's error mapping; the connection itself runs against the T1 server (#161).

import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/enough_connection_tester.dart';
import 'package:postino/core/domain/result.dart';

void main() {
  final imap = ImapClient();
  final smtp = SmtpClient('localhost');

  test('a NO at the login on a live connection is a refusal of the credentials', () {
    expect(testConnectionFailure(ImapException(imap, 'NO'), atLogin: true, connected: true), isA<AuthFailure>());
    expect(
      testConnectionFailure(SmtpException.message(smtp, '535'), atLogin: true, connected: true),
      isA<AuthFailure>(),
    );
  });

  test('a timeout or a lost connection, also at the login, is an unreachable server', () {
    expect(
      testConnectionFailure(ImapException(imap, 'timeout'), atLogin: true, connected: true),
      isA<OfflineFailure>(),
    );
    expect(
      testConnectionFailure(ImapException(imap, 'connection lost'), atLogin: true, connected: false),
      isA<OfflineFailure>(),
    );
    // STARTTLS chosen on port 993: the greeting never arrives.
    expect(
      testConnectionFailure(ImapException(imap, 'no greeting'), atLogin: false, connected: false),
      isA<OfflineFailure>(),
    );
    for (final e in [const SocketException('x'), const TlsException('x'), TimeoutException('x')]) {
      expect(testConnectionFailure(e, atLogin: true, connected: true), isA<OfflineFailure>());
    }
  });

  test('a protocol error after the login is unexpected', () {
    expect(
      testConnectionFailure(ImapException(imap, 'BAD'), atLogin: false, connected: true),
      isA<UnexpectedFailure>(),
    );
  });
}
