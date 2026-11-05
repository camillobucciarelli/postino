import 'package:equatable/equatable.dart';

import 'result.dart';

/// What Google hands back after the user consents.
class const GoogleGrant({
  /// Indirizzo dell'identità Google che ha dato il consenso.
  required final String address,

  /// Token di accesso alle API Gmail.
  required final String accessToken,

  /// Token per ottenere nuovi token di accesso.
  required final String refreshToken,

  /// Scadenza del token di accesso.
  required final DateTime expiresAt,
}) extends Equatable {
  /// Crea la concessione con i token ricevuti da Google.
  this;

  /// Never stringified: the tokens must not end up in logs.
  @override
  bool get stringify => false;

  @override
  List<Object?> get props => [address, accessToken, refreshToken, expiresAt];
}

/// Thin seam over the Google OAuth consent (real one in core/data, fake in widget tests).
abstract interface class GoogleConsent() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// [loginHint] preselects the Google account, for the reconnection of a Da ricollegare Account.
  /// [drive] asks also for the `drive.appdata` scope on top of those already granted (incremental consent,
  /// ADR 0016): the grant keeps the Gmail scope, and without the Drive one the result is [DriveScopeFailure].
  Future<Result<GoogleGrant>> run({String? loginHint, bool drive = false});
}
