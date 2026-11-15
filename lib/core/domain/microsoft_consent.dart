import 'oauth_grant.dart';
import 'result.dart';

/// Thin seam over the Microsoft consent (real one in core/data, fake in widget tests).
abstract interface class MicrosoftConsent() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Consent of a personal (Outlook.com, Hotmail, Live) or work or school Microsoft account (Microsoft 365) for the
  /// mail scopes; [loginHint] preselects the account, for the reconnection of a Da ricollegare Account. A grant
  /// without the permission to read and send mail is [MissingPermissionFailure]; the organization's refusal is
  /// [AdminConsentFailure] (an administrator must approve the app) or [OrganizationPolicyFailure].
  Future<Result<OAuthGrant>> run({String? loginHint});
}
