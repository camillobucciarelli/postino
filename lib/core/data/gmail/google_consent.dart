import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

import '../../domain/google_consent.dart';
import '../../domain/oauth_grant.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../oauth/oauth_authorize.dart';
import '../oauth/oauth_browser.dart';
import '../oauth/oauth_exchange.dart';
import 'google_client.dart';

/// Google consent in the system browser (authorization code + PKCE), then code exchange.
@Singleton(as: GoogleConsent, env: [Environment.prod])
class GoogleWebConsent(
  final http.Client _http,
  final Clock _clock, {
  @ignoreParam final GoogleClient _client = const GoogleClient.fromEnvironment(),
  @ignoreParam final Authenticate _authenticate = systemBrowser,
  @ignoreParam bool? loopback,
}) implements GoogleConsent {
  this : _loopback = loopback ?? loopbackRedirectPlatform;

  final bool _loopback;

  static const _gmailScope = 'https://mail.google.com/';
  static const _driveScope = 'https://www.googleapis.com/auth/drive.appdata';
  static const _scopes = '$_gmailScope openid email';

  @override
  Future<Result<OAuthGrant>> run({String? loginHint, bool drive = false}) async {
    if (_client.id.isEmpty) {
      return const Err(ConfigurationFailure('GOOGLE_CLIENT_ID'));
    }
    // iOS/Android/macOS: the reversed client ID is the callback scheme Google accepts.
    final scheme = _loopback
        ? loopbackRedirect
        : 'com.googleusercontent.apps.${_client.id.replaceFirst('.apps.googleusercontent.com', '')}';
    final redirect = _loopback ? scheme : '$scheme:/oauth2redirect';
    final AuthorizationCode code;
    switch (await authorizeInBrowser(
      authenticate: _authenticate,
      endpoint: Uri.https('accounts.google.com', '/o/oauth2/v2/auth'),
      query: {
        'client_id': _client.id,
        'scope': drive ? '$_scopes $_driveScope' : _scopes,
        if (drive) 'include_granted_scopes': 'true',
        // Without these Google may skip the refresh_token for an already-authorized client.
        'access_type': 'offline',
        'prompt': 'consent',
        'login_hint': ?loginHint,
      },
      redirect: redirect,
      callbackScheme: scheme,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        code = value;
    }
    final TokenResponse tokens;
    switch (await exchangeCode(_http, _client, code)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        tokens = value;
    }
    // Granular consent: the user can untick the Gmail permission and still get tokens.
    if (!tokens.scopes.contains(_gmailScope)) return const Err(MissingPermissionFailure());
    if (drive && !tokens.scopes.contains(_driveScope)) return const Err(DriveScopeFailure());
    final address = tokens.claims['email'];
    if (address is! String) return const Err(UnexpectedFailure('no email in id_token'));
    return tokens.grant(address: address, clock: _clock);
  }
}
