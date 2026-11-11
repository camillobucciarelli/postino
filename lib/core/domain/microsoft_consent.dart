import 'oauth_grant.dart';
import 'result.dart';

/// Thin seam over the Microsoft consent (real one in core/data, fake in widget tests).
abstract interface class MicrosoftConsent() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Consent of a personal Microsoft account (Outlook.com, Hotmail, Live) for the mail scopes; [loginHint]
  /// preselects the account, for the reconnection of a Da ricollegare Account. A work or school identity is
  /// [WorkAccountFailure], a grant without the permission to read and send mail [MissingPermissionFailure].
  Future<Result<OAuthGrant>> run({String? loginHint});
}
