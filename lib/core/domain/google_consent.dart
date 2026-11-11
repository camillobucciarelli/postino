import 'oauth_grant.dart';
import 'result.dart';

/// Thin seam over the Google OAuth consent (real one in core/data, fake in widget tests).
abstract interface class GoogleConsent() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// [loginHint] preselects the Google account, for the reconnection of a Da ricollegare Account.
  /// [drive] asks also for the `drive.appdata` scope on top of those already granted (incremental consent,
  /// ADR 0016): the grant keeps the Gmail scope, and without the Drive one the result is [DriveScopeFailure].
  Future<Result<OAuthGrant>> run({String? loginHint, bool drive = false});
}
