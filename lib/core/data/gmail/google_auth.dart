import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import 'gmail_tokens.dart';
import 'google_client.dart';
import 'google_failure.dart';

/// The OAuth tokens of a Google Account for any Google API (Gmail, Drive): from the keychain, refreshed when
/// they expire. Failures are thrown as [GoogleFailed].
class GoogleAuth(
  final String _accountId,
  final SecureStore _keychain,
  final http.Client _http,
  final Clock _clock, {
  required final GoogleClient _client,
}) {
  static final _tokenEndpoint = Uri.parse('https://oauth2.googleapis.com/token');

  /// The tokens in the keychain, as they are.
  Future<GmailTokens?> tokens() => GmailTokens.read(_keychain, _accountId);

  /// Tokens with an access token still valid for at least a minute.
  Future<GmailTokens> validTokens() async {
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
  Future<GmailTokens> refresh(GmailTokens? old) async {
    if (old == null) throw const GoogleFailed(AuthFailure());
    final r = await _http.post(
      _tokenEndpoint,
      body: {'grant_type': 'refresh_token', 'refresh_token': old.refresh, ..._client.fields},
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 200) {
      final fresh = GmailTokens(
        access: body['access_token'] as String,
        // Google may rotate it.
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
      throw const GoogleFailed(AuthFailure());
    }
    throw GoogleFailed(UnexpectedFailure('token refresh: HTTP ${r.statusCode}'));
  }
}
