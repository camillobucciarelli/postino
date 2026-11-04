import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

import '../../domain/google_consent.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import 'google_client.dart';

/// Opens [url] in the system browser and returns the callback URL.
typedef Authenticate = Future<String> Function({required String url, required String callbackUrlScheme});

Future<String> _systemBrowser({required String url, required String callbackUrlScheme}) => FlutterWebAuth2.authenticate(
  url: url,
  callbackUrlScheme: callbackUrlScheme,
  // Google refuses consent inside embedded webviews.
  options: const FlutterWebAuth2Options(useWebview: false),
);

/// Google consent in the system browser (authorization code + PKCE), then code exchange.
@Singleton(as: GoogleConsent, env: [Environment.prod])
class GoogleWebConsent implements GoogleConsent {
  GoogleWebConsent(
    this._http,
    this._clock, [
    @ignoreParam this._client = const GoogleClient.fromEnvironment(),
    @ignoreParam this._authenticate = _systemBrowser,
    @ignoreParam bool? loopback,
  ]) : _loopback = loopback ?? (Platform.isWindows || Platform.isLinux);

  final http.Client _http;
  final Clock _clock;
  final GoogleClient _client;
  final Authenticate _authenticate;

  /// Windows/Linux have no app callback scheme: a "Desktop app" client redirects to localhost.
  final bool _loopback;

  // ponytail: fixed loopback port; pick a free one if it ever clashes.
  static const _loopbackRedirect = 'http://localhost:53682';
  static const _gmailScope = 'https://mail.google.com/';
  static const _scopes = '$_gmailScope openid email';

  @override
  Future<Result<GoogleGrant>> run({String? loginHint}) async {
    if (_client.id.isEmpty) {
      return const Err(ConfigurationFailure('GOOGLE_CLIENT_ID'));
    }
    // iOS/Android/macOS: the reversed client ID is the callback scheme Google accepts.
    final scheme = _loopback
        ? _loopbackRedirect
        : 'com.googleusercontent.apps.${_client.id.replaceFirst('.apps.googleusercontent.com', '')}';
    final redirect = _loopback ? scheme : '$scheme:/oauth2redirect';
    final verifier = _random();
    final state = _random();
    try {
      final callback = Uri.parse(
        await _authenticate(
          url: Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
            'client_id': _client.id,
            'redirect_uri': redirect,
            'response_type': 'code',
            'scope': _scopes,
            'code_challenge': base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', ''),
            'code_challenge_method': 'S256',
            'state': state,
            // Without these Google may skip the refresh_token for an already-authorized client.
            'access_type': 'offline',
            'prompt': 'consent',
            'login_hint': ?loginHint,
          }).toString(),
          callbackUrlScheme: scheme,
        ),
      ).queryParameters;
      if (callback['state'] != state) {
        return const Err(UnexpectedFailure('OAuth state mismatch'));
      }
      final code = callback['code'];
      if (code == null) return const Err(CancelledFailure()); // access_denied
      final r = await _http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'code_verifier': verifier,
          'redirect_uri': redirect,
          ..._client.fields,
        },
      );
      if (r.statusCode != 200) {
        return Err(UnexpectedFailure('code exchange: HTTP ${r.statusCode}'));
      }
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      // Granular consent: the user can untick the Gmail permission and still get tokens.
      if (!((body['scope'] as String?) ?? '').split(' ').contains(_gmailScope)) {
        return const Err(MissingPermissionFailure());
      }
      final refreshToken = body['refresh_token'] as String?;
      if (refreshToken == null) {
        return const Err(UnexpectedFailure('no refresh_token in code exchange'));
      }
      // The id_token comes straight from Google's token endpoint over TLS: its payload needs no signature check.
      final idToken = (body['id_token'] as String).split('.')[1];
      final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(idToken)))) as Map<String, dynamic>;
      return Ok(
        GoogleGrant(
          address: claims['email'] as String,
          accessToken: body['access_token'] as String,
          refreshToken: refreshToken,
          expiresAt: _clock.now().add(Duration(seconds: body['expires_in'] as int)),
        ),
      );
    } on PlatformException catch (e) {
      return e.code == 'CANCELED' ? const Err(CancelledFailure()) : Err(UnexpectedFailure(e));
    } on http.ClientException {
      return const Err(OfflineFailure());
    } catch (e, s) {
      return Err(UnexpectedFailure(e, s));
    }
  }

  static String _random() {
    final r = Random.secure();
    return base64Url.encode([for (var i = 0; i < 32; i++) r.nextInt(256)]).replaceAll('=', '');
  }
}
