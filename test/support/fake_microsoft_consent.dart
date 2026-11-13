import 'package:postino/core/domain/microsoft_consent.dart';
import 'package:postino/core/domain/oauth_grant.dart';
import 'package:postino/core/domain/result.dart';

/// Consent that always succeeds for [address], with fresh tokens each run (unless [failure] is set).
class FakeMicrosoftConsent() implements MicrosoftConsent {
  String address = 'ada@outlook.com';
  Failure? failure;
  int runs = 0;
  String? lastLoginHint;

  /// While set, the consent waits for it (the user is on Microsoft's page).
  Future<void>? gate;

  @override
  Future<Result<OAuthGrant>> run({String? loginHint}) async {
    lastLoginHint = loginHint;
    await gate;
    final f = failure;
    if (f != null) return Err(f);
    runs++;
    return Ok(
      OAuthGrant(
        address: address,
        accessToken: 'ms-access-token-$runs',
        refreshToken: 'ms-refresh-token-$runs',
        expiresAt: DateTime.utc(2030),
      ),
    );
  }
}
