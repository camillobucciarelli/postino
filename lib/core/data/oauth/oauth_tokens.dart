import 'dart:convert';

import '../../domain/oauth_grant.dart';
import '../../domain/platform_services.dart';

/// OAuth tokens of an Account (Gmail, Microsoft), under the same key for every Provider: they live only in the keychain, never in the database.
class const OAuthTokens({
  required final String access,
  required final String refresh,
  required final DateTime expiresAt,

  /// The scopes granted to [refresh]; empty for tokens saved before they were kept (#321), until a refresh tells them.
  final List<String> scopes = const [],
}) {
  OAuthTokens.of(OAuthGrant g)
    : this(access: g.accessToken, refresh: g.refreshToken, expiresAt: g.expiresAt, scopes: g.scopes);

  /// The keychain item of [accountId].
  static String keychainKey(String accountId) => 'oauth:$accountId';

  static Future<OAuthTokens?> read(SecureStore keychain, String accountId) async {
    final raw = await keychain.read(keychainKey(accountId));
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return OAuthTokens(
      access: j['access'] as String,
      refresh: j['refresh'] as String,
      expiresAt: DateTime.parse(j['expiresAt'] as String),
      scopes: [for (final s in j['scopes'] as List<dynamic>? ?? const []) s as String],
    );
  }

  /// Forgets the tokens of [accountId]: the Account was removed.
  static Future<void> delete(SecureStore keychain, String accountId) => keychain.delete(keychainKey(accountId));

  Future<void> write(SecureStore keychain, String accountId) => keychain.write(
    keychainKey(accountId),
    jsonEncode({
      'access': access,
      'refresh': refresh,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      if (scopes.isNotEmpty) 'scopes': scopes,
    }),
  );

  /// Never the tokens: they must not end up in logs.
  @override
  String toString() => 'OAuthTokens';
}
