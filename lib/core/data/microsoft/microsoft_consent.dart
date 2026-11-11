import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

import '../../domain/microsoft_consent.dart';
import '../../domain/oauth_grant.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../oauth/oauth_authorize.dart';
import '../oauth/oauth_browser.dart';
import '../oauth/oauth_exchange.dart';
import 'microsoft_client.dart';

/// Microsoft consent in the system browser (authorization code + PKCE, `consumers` endpoint), then code exchange.
@Singleton(as: MicrosoftConsent, env: [Environment.prod])
class MicrosoftWebConsent(
  final http.Client _http,
  final Clock _clock, {
  @ignoreParam final MicrosoftClient _client = const MicrosoftClient.fromEnvironment(),
  @ignoreParam final Authenticate _authenticate = systemBrowser,
  @ignoreParam bool? loopback,
}) implements MicrosoftConsent {
  this : _loopback = loopback ?? loopbackRedirectPlatform;

  final bool _loopback;

  /// The tenant of every personal Microsoft account: any other `tid` is a work or school identity.
  static const personalTenant = '9188040d-6c67-4c5b-b112-36a304b66dad';

  // Polling only for Microsoft in v1: no IMAP.AccessAsUser.All (the IDLE signal), decided with the owner.
  static const _scopes = 'openid email offline_access User.Read Mail.ReadWrite Mail.Send';
  static const _mailScopes = ['mail.readwrite', 'mail.send'];
  static const _graph = 'https://graph.microsoft.com/';

  @override
  Future<Result<OAuthGrant>> run({String? loginHint}) async {
    if (_client.id.isEmpty) {
      return const Err(ConfigurationFailure('MICROSOFT_CLIENT_ID'));
    }
    // iOS/Android/macOS: the `msal<id>` scheme registered with the app; Windows/Linux: loopback.
    final scheme = _loopback ? loopbackRedirect : 'msal${_client.id}';
    final redirect = _loopback ? scheme : '$scheme://auth';
    final AuthorizationCode code;
    switch (await authorizeInBrowser(
      authenticate: _authenticate,
      endpoint: MicrosoftClient.authorizeEndpoint,
      query: {'client_id': _client.id, 'scope': _scopes, 'prompt': 'select_account', 'login_hint': ?loginHint},
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
    if (tokens.claims['tid'] != personalTenant) return const Err(WorkAccountFailure());
    // The scopes come back with or without the Graph prefix, in any case.
    final granted = {for (final s in tokens.scopes) s.toLowerCase().replaceFirst(_graph, '')};
    if (!granted.containsAll(_mailScopes)) return const Err(MissingPermissionFailure());
    final address = tokens.claims['email'] ?? tokens.claims['preferred_username'];
    if (address is! String) return const Err(UnexpectedFailure('no address in id_token'));
    return tokens.grant(address: address.trim().toLowerCase(), clock: _clock);
  }
}
