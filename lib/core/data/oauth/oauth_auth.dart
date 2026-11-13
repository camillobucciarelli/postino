import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import 'oauth_client.dart';
import 'oauth_failed.dart';
import 'oauth_tokens.dart';

/// The OAuth tokens of an Account for any API of its Provider (Gmail, Drive, Graph): from the keychain, refreshed
/// when they expire. Failures are thrown as [OAuthFailed].
class OAuthAuth(
  final String _accountId,
  final SecureStore _keychain,
  final http.Client _http,
  final Clock _clock, {
  required final OAuthClient _client,
}) {
  /// The tokens in the keychain, as they are.
  Future<OAuthTokens?> tokens() => OAuthTokens.read(_keychain, _accountId);

  /// Tokens with an access token still valid for at least a minute.
  Future<OAuthTokens> validTokens() async {
    final tokens = await this.tokens();
    if (tokens != null && _clock.now().isBefore(tokens.expiresAt.subtract(const Duration(minutes: 1)))) {
      return tokens;
    }
    return refresh(tokens);
  }

  /// [send] with a valid access token; on a 401 the token is refreshed once and [send] runs again.
  Future<http.Response> authorized(Future<http.Response> Function(String access) send) async {
    final tokens = await validTokens();
    final r = await send(tokens.access);
    if (r.statusCode != 401) return r;
    return send((await refresh(tokens)).access);
  }

  /// A new access token from the refresh token of [old], saved in the keychain.
  /// A revoked or expired refresh token is the Provider's definitive refusal: [AuthFailure].
  Future<OAuthTokens> refresh(OAuthTokens? old) async {
    if (old == null) throw const OAuthFailed(AuthFailure());
    final r = await _http.post(
      _client.tokenEndpoint,
      body: {'grant_type': 'refresh_token', 'refresh_token': old.refresh, ..._client.fields},
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 200) {
      final fresh = OAuthTokens(
        access: body['access_token'] as String,
        // The Provider may rotate it (Microsoft always does).
        refresh: body['refresh_token'] as String? ?? old.refresh,
        expiresAt: _clock.now().add(Duration(seconds: body['expires_in'] as int)),
      );
      // Only over the tokens this refresh started from (#174): the Account removed meanwhile has none, and one
      // connected again has newer ones, which an old grant must not overwrite.
      // ponytail: a change between this read and the write still races it; a per-Account lock if that ever shows.
      if ((await tokens())?.refresh == old.refresh) await fresh.write(_keychain, _accountId);
      return fresh;
    }
    if (r.statusCode == 401 || body['error'] == 'invalid_grant') {
      throw const OAuthFailed(AuthFailure());
    }
    throw OAuthFailed(UnexpectedFailure('token refresh: HTTP ${r.statusCode}'));
  }
}
