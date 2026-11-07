import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';

import '../../domain/result.dart';

/// A [Failure] already mapped, thrown inside the IMAP adapter and turned into an [Err] by [imapGuard].
class const ImapFailed(final Failure failure) implements Exception {
  @override
  String toString() => 'ImapFailed($failure)';
}

/// Runs [body]: an [ImapFailed] is its failure, anything else thrown is unexpected.
Future<Result<T>> imapGuard<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on ImapFailed catch (e) {
    return Err(e.failure);
  } on Object catch (e) {
    return Err(UnexpectedFailure(e));
  }
}

/// The Failure of [error], thrown [atLogin] or not, with the connection still up ([connected]) or not.
/// enough_mail reports a timeout and a lost connection with the same exception as a server's NO: only a protocol
/// error at the login on a live connection is a refusal of the credentials, unless the server says it is only
/// unavailable for now (RFC 5530 `[UNAVAILABLE]`). Never carries the password: the login command is not part of
/// any exception enough_mail throws.
Failure imapFailure(Object error, {required bool atLogin, required bool connected}) => switch (error) {
  ImapFailed(:final failure) => failure,
  SocketException() || TlsException() || TimeoutException() => const OfflineFailure(),
  ImapException(message: 'timeout') => const OfflineFailure(),
  ImapException() || SmtpException() when !connected => const OfflineFailure(),
  ImapException(:final message?) when atLogin && message.contains('UNAVAILABLE') => const OfflineFailure(),
  ImapException() || SmtpException() when atLogin => const AuthFailure(),
  _ => UnexpectedFailure(error),
};
