import 'result.dart';

/// What Google hands back after the user consents.
class GoogleGrant {
  const GoogleGrant({
    required this.address,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });
  final String address;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
}

/// Thin seam over the Google OAuth consent (real one in core/data, fake in widget tests).
abstract interface class GoogleConsent {
  /// [loginHint] preselects the Google account, for the reconnection of a Da ricollegare Account.
  Future<Result<GoogleGrant>> run({String? loginHint});
}
