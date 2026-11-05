import 'package:postino/core/domain/google_consent.dart';
import 'package:postino/core/domain/result.dart';

/// Consent that always succeeds for [address], with fresh tokens each run (unless [failure] is set).
class FakeGoogleConsent() implements GoogleConsent {
  String address = 'ada@gmail.com';
  Failure? failure;
  int runs = 0;
  String? lastLoginHint;
  bool? lastDrive;

  /// While set, the consent waits for it (the user is on Google's page).
  Future<void>? gate;

  @override
  Future<Result<GoogleGrant>> run({String? loginHint, bool drive = false}) async {
    lastLoginHint = loginHint;
    lastDrive = drive;
    await gate;
    final f = failure;
    if (f != null) return Err(f);
    runs++;
    return Ok(
      GoogleGrant(
        address: address,
        accessToken: 'access-token-$runs',
        refreshToken: 'refresh-token-$runs',
        expiresAt: DateTime.utc(2030),
      ),
    );
  }
}
