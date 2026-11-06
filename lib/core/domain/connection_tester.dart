import 'mail_servers.dart';
import 'result.dart';

/// The test connection made before saving a password Account. The real one in core/data.
abstract interface class ConnectionTester() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// IMAP login + LIST and SMTP EHLO + AUTH on [servers] as [user] with [password]. A refused login is
  /// [AuthFailure], a server that cannot be reached [OfflineFailure]. Never throws.
  Future<Result<void>> test(ServerSettings servers, {required String user, required String password});
}
