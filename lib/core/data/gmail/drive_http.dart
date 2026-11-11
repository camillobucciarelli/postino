import 'dart:async';

import 'package:http/http.dart' as http;

import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../oauth/oauth_auth.dart';
import '../oauth/oauth_failed.dart';
import 'google_client.dart';
import 'google_failure.dart';

/// Drive v3 over HTTP for one Account: the transport under `DriveSettingsBackend`, as `GmailHttp` is under
/// `GmailProvider`. Never an [AuthFailure] for a missing scope: that is a [DriveScopeFailure], so the Account's
/// mail is never marked Da ricollegare because of Drive.
class DriveHttp(
  String accountId,
  SecureStore keychain,
  final http.Client _http,
  Clock clock, {
  GoogleClient client = const GoogleClient.fromEnvironment(),
  final Duration _timeout = const Duration(seconds: 30),
}) {
  this : _auth = OAuthAuth(accountId, keychain, _http, clock, client: client);

  final OAuthAuth _auth;

  /// A Drive call with a valid token, refreshed once more on a 401. Token and request together get at most
  /// [_timeout], so a stalled refresh never holds the caller; anything but a 200 or 204 throws a [OAuthFailed].
  Future<http.Response> send(String method, Uri url, {String? body, String? type}) async {
    final abort = Completer<void>();
    final http.Response r;
    try {
      r = await _auth
          .authorized((access) {
            final request = http.AbortableRequest(method, url, abortTrigger: abort.future)
              ..headers['authorization'] = 'Bearer $access';
            if (body != null) {
              request
                ..headers['content-type'] = type!
                ..body = body;
            }
            return _http.send(request).then(http.Response.fromStream);
          })
          .timeout(_timeout);
    } on TimeoutException {
      // A request still in flight is dropped, never left to finish behind a retry.
      abort.complete();
      rethrow;
    }
    if (r.statusCode == 200 || r.statusCode == 204) return r;
    throw OAuthFailed(switch (r.statusCode) {
      _ when googleRateLimited(r) => const RateLimitFailure(),
      // The token lacks drive.appdata: only the incremental consent fixes it.
      _ when googleScopeMissing(r) => const DriveScopeFailure(),
      404 => const NotFoundFailure(),
      _ => UnexpectedFailure('Drive: HTTP ${r.statusCode}'),
    });
  }
}
