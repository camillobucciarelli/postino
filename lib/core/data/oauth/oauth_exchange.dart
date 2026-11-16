import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/oauth_grant.dart';
import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import 'oauth_authorize.dart';
import 'oauth_client.dart';
import 'oauth_refusal.dart';

/// The token endpoint's answer to a code exchange.
class const TokenResponse({
  required final String accessToken,
  required final String? refreshToken,
  required final int expiresIn,
  required final List<String> scopes,

  /// The payload of the `id_token`.
  required final Map<String, dynamic> claims,
}) {
  /// The grant for [address]; a response without a refresh token cannot keep the Account connected.
  Result<OAuthGrant> grant({required String address, required Clock clock}) {
    final refresh = refreshToken;
    if (refresh == null) return const Err(UnexpectedFailure('no refresh_token in code exchange'));
    return Ok(
      OAuthGrant(
        address: address,
        accessToken: accessToken,
        refreshToken: refresh,
        expiresAt: clock.now().add(Duration(seconds: expiresIn)),
        scopes: scopes,
      ),
    );
  }

  /// Never stringified: the tokens must not end up in logs.
  @override
  String toString() => 'TokenResponse';
}

/// Exchanges [code] for tokens at the client's token endpoint. Never throws: no network is [OfflineFailure], an
/// organization's refusal its [organizationRefusal].
Future<Result<TokenResponse>> exchangeCode(http.Client client, OAuthClient oauth, AuthorizationCode code) async {
  try {
    final r = await client.post(
      oauth.tokenEndpoint,
      body: {
        'grant_type': 'authorization_code',
        'code': code.code,
        'code_verifier': code.verifier,
        'redirect_uri': code.redirect,
        ...oauth.fields,
      },
    );
    if (r.statusCode != 200) {
      final error = _errorBody(r.body);
      return Err(
        organizationRefusal(error['error'] as String?, error['error_description'] as String?) ??
            UnexpectedFailure('code exchange: HTTP ${r.statusCode}'),
      );
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    // The id_token comes straight from the token endpoint over TLS: its payload needs no signature check.
    final idToken = (body['id_token'] as String).split('.')[1];
    return Ok(
      TokenResponse(
        accessToken: body['access_token'] as String,
        refreshToken: body['refresh_token'] as String?,
        expiresIn: body['expires_in'] as int,
        scopes: [
          for (final s in ((body['scope'] as String?) ?? '').split(' '))
            if (s.isNotEmpty) s,
        ],
        claims: jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(idToken)))) as Map<String, dynamic>,
      ),
    );
  } on http.ClientException {
    return const Err(OfflineFailure());
  } on Object catch (e, s) {
    return Err(UnexpectedFailure(e, s));
  }
}

/// The JSON error of a refused request; empty when the body is not one.
Map<String, dynamic> _errorBody(String body) {
  try {
    return jsonDecode(body) as Map<String, dynamic>;
  } on Object {
    return const {};
  }
}
