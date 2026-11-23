import 'dart:async';
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

  /// The token endpoint answers within this, or the refresh is an [OfflineFailure]: a refresh that hangs would hold
  /// the Account's sync queue for good. Never a stalled request: no call of the Account can go on without a token.
  final Duration _refreshWithin = const Duration(seconds: 30),

  /// The keychain answers within this (#251): one that never does (locked, or waiting behind a system prompt) would
  /// hold the Account's queue with no error at all.
  final Duration _keychainWithin = const Duration(seconds: 60),
}) {
  /// The tokens in the keychain, as they are.
  Future<OAuthTokens?> tokens() => _inTime(OAuthTokens.read(_keychain, _accountId));

  /// [keychainCall], or an [OfflineFailure] that names the keychain in the error log.
  Future<T> _inTime<T>(Future<T> keychainCall) => keychainCall.timeout(
    _keychainWithin,
    onTimeout: () => throw const OAuthFailed(OfflineFailure(detail: 'keychain did not answer')),
  );

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
  /// A revoked or expired refresh token, or one that needs the user to sign in again, is the Provider's definitive
  /// refusal: [AuthFailure]. Before that the keychain is read again, never Drive: a refresh token that came from
  /// another device meanwhile (ADR 0019) is tried once. Any other refusal (the client, not the token: #353) is an
  /// [UnexpectedFailure], and the Account stays connected.
  Future<OAuthTokens> refresh(OAuthTokens? old) => _refresh(old, again: true);

  Future<OAuthTokens> _refresh(OAuthTokens? old, {required bool again}) async {
    if (old == null) throw const OAuthFailed(AuthFailure(reason: 'token refresh: no tokens here'));
    final r = await _http
        .post(
          _client.tokenEndpoint,
          body: {'grant_type': 'refresh_token', 'refresh_token': old.refresh, ..._client.fields},
        )
        .timeout(
          _refreshWithin,
          onTimeout: () =>
              throw OAuthFailed(OfflineFailure(detail: 'token refresh: ${_client.tokenEndpoint.host}, no answer')),
        );
    final body = _json(r.body);
    // The Provider's own trouble (or a proxy's page in its place), not a refusal: tried again by the next sync.
    if (r.statusCode >= 500) throw OAuthFailed(OfflineFailure(detail: _refusal(r.statusCode, body, old)));
    if (r.statusCode == 200) {
      final fresh = OAuthTokens(
        access: body['access_token'] as String,
        // The Provider may rotate it (Microsoft always does).
        refresh: body['refresh_token'] as String? ?? old.refresh,
        expiresAt: _clock.now().add(Duration(seconds: body['expires_in'] as int)),
        // Learnt once, for tokens saved before the scopes were kept (#321): afterwards only a consent changes them,
        // so two devices never take turns over how a refresh and a consent spell them.
        scopes: old.scopes.isNotEmpty
            ? old.scopes
            : [
                for (final s in ((body['scope'] as String?) ?? '').split(' '))
                  if (s.isNotEmpty) s,
              ],
        // A refresh token rotated here is this device's own.
        synced: old.synced && (body['refresh_token'] ?? old.refresh) == old.refresh,
      );
      // Only over the tokens this refresh started from (#174): the Account removed meanwhile has none, and one
      // connected again has newer ones, which an old grant must not overwrite.
      // ponytail: a change between this read and the write still races it; a per-Account lock if that ever shows.
      if ((await tokens())?.refresh == old.refresh) await _inTime(fresh.write(_keychain, _accountId));
      return fresh;
    }
    final why = _refusal(r.statusCode, body, old);
    // interaction_required: the organization wants the user to sign in again (MFA, Conditional Access).
    if (body['error'] == 'invalid_grant' || body['error'] == 'interaction_required') {
      // A keychain that cannot be read now is no other token: the refusal stands.
      final now = again ? await tokens().catchError((Object _) => null) : null;
      if (now != null && now.refresh != old.refresh) return _refresh(now, again: false);
      throw OAuthFailed(AuthFailure(reason: why));
    }
    throw OAuthFailed(UnexpectedFailure(why));
  }

  /// The JSON object of an answer; empty when the body is not one (a gateway's HTML page).
  static Map<String, dynamic> _json(String body) {
    try {
      if (jsonDecode(body) case final Map<String, dynamic> json) return json;
    } on FormatException catch (_) {}
    return const {};
  }

  /// The refusal for the error log: the Provider's host, the status, the `error` code and, from the description,
  /// only Microsoft's `AADSTS…` code (the rest may name the user); whether the token came from the synced file.
  String _refusal(int status, Map<String, dynamic> body, OAuthTokens old) {
    final error = '${body['error'] ?? 'no error'}';
    final code = RegExp(r'AADSTS\d+').firstMatch('${body['error_description'] ?? ''}')?.group(0);
    return [
      'token refresh: ${_client.tokenEndpoint.host}',
      'HTTP $status',
      // ponytail: an OAuth error code is a short identifier; cut, in case a Provider ever puts more there.
      [error.length > 40 ? error.substring(0, 40) : error, ?code].join(' '),
      if (old.synced) 'synced token',
    ].join(', ');
  }
}
