import 'package:flutter/services.dart';

import '../../domain/result.dart';
import 'oauth_browser.dart';
import 'oauth_pkce.dart';
import 'oauth_refusal.dart';

/// The authorization code the browser returned, with what the token exchange needs along with it.
class const AuthorizationCode({
  required final String code,
  required final String verifier,
  required final String redirect,
}) {
  /// Never stringified: the code must not end up in logs.
  @override
  String toString() => 'AuthorizationCode';
}

/// The authorization request of an authorization code + PKCE (S256) flow in the system browser: [query] has what is
/// specific to the Provider (client, scope, hints), the rest is added here. The `state` of the callback is checked;
/// a callback without a code is the user backing out ([CancelledFailure]) or an [organizationRefusal]. Never throws.
Future<Result<AuthorizationCode>> authorizeInBrowser({
  required Authenticate authenticate,
  required Uri endpoint,
  required Map<String, String> query,
  required String redirect,
  required String callbackScheme,
}) async {
  final verifier = randomUrlSafe();
  final state = randomUrlSafe();
  try {
    final callback = Uri.parse(
      await authenticate(
        url: endpoint
            .replace(
              queryParameters: {
                ...query,
                'redirect_uri': redirect,
                'response_type': 'code',
                'code_challenge': pkceChallenge(verifier),
                'code_challenge_method': 'S256',
                'state': state,
              },
            )
            .toString(),
        callbackUrlScheme: callbackScheme,
      ),
    ).queryParameters;
    if (callback['state'] != state) return const Err(UnexpectedFailure('OAuth state mismatch'));
    final code = callback['code'];
    if (code == null) {
      // An organization's refusal has its own message; access_denied is the user backing out; any other error is a
      // failure to show (a misregistered redirect, say).
      final error = callback['error'];
      if (organizationRefusal(error, callback['error_description']) case final refusal?) return Err(refusal);
      return error == null || error == 'access_denied'
          ? const Err(CancelledFailure())
          : Err(UnexpectedFailure('OAuth error: $error'));
    }
    return Ok(AuthorizationCode(code: code, verifier: verifier, redirect: redirect));
  } on PlatformException catch (e) {
    return e.code == 'CANCELED' ? const Err(CancelledFailure()) : Err(UnexpectedFailure(e));
  } on Object catch (e, s) {
    return Err(UnexpectedFailure(e, s));
  }
}
