import 'package:equatable/equatable.dart';

import 'result.dart';

/// What Google hands back after the user consents.
class const GoogleGrant({
  required this.address,
  required this.accessToken,
  required this.refreshToken,
  required this.expiresAt,
}) extends Equatable {
  /// Crea la concessione con i token ricevuti da Google.
  this;

  /// Indirizzo dell'identità Google che ha dato il consenso.
  final String address;

  /// Token di accesso alle API Gmail.
  final String accessToken;

  /// Token per ottenere nuovi token di accesso.
  final String refreshToken;

  /// Scadenza del token di accesso.
  final DateTime expiresAt;

  /// Never stringified: the tokens must not end up in logs.
  @override
  bool get stringify => false;

  @override
  List<Object?> get props => [address, accessToken, refreshToken, expiresAt];
}

/// Thin seam over the Google OAuth consent (real one in core/data, fake in widget tests).
// ignore: public_member_api_docs, costruttore implicito di classe astratta
abstract interface class GoogleConsent() {
  /// [loginHint] preselects the Google account, for the reconnection of a Da ricollegare Account.
  Future<Result<GoogleGrant>> run({String? loginHint});
}
