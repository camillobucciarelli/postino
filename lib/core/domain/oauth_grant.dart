import 'package:equatable/equatable.dart';

/// What an OAuth Provider (Google, Microsoft) hands back after the user consents.
class const OAuthGrant({
  /// Indirizzo dell'identità che ha dato il consenso.
  required final String address,

  /// Token di accesso alle API del Provider.
  required final String accessToken,

  /// Token per ottenere nuovi token di accesso.
  required final String refreshToken,

  /// Scadenza del token di accesso.
  required final DateTime expiresAt,

  /// The scopes the Provider granted to the token; empty when unknown.
  final List<String> scopes = const [],
}) extends Equatable {
  /// Crea la concessione con i token ricevuti dal Provider.
  this;

  /// Never stringified: the tokens must not end up in logs.
  @override
  bool get stringify => false;

  @override
  List<Object?> get props => [address, accessToken, refreshToken, expiresAt, scopes];
}
