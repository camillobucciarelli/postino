import 'dart:convert';

import '../../domain/google_consent.dart';
import '../../domain/platform_services.dart';

/// OAuth tokens of a Gmail Account: they live only in the keychain, never in the database.
class const GmailTokens({
  required final String access,
  required final String refresh,
  required final DateTime expiresAt,
}) {
  GmailTokens.of(GoogleGrant g) : this(access: g.accessToken, refresh: g.refreshToken, expiresAt: g.expiresAt);

  static String _key(String accountId) => 'oauth:$accountId';

  static Future<GmailTokens?> read(SecureStore keychain, String accountId) async {
    final raw = await keychain.read(_key(accountId));
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return GmailTokens(
      access: j['access'] as String,
      refresh: j['refresh'] as String,
      expiresAt: DateTime.parse(j['expiresAt'] as String),
    );
  }

  static Future<void> delete(SecureStore keychain, String accountId) => keychain.delete(_key(accountId));

  Future<void> write(SecureStore keychain, String accountId) => keychain.write(
    _key(accountId),
    jsonEncode({'access': access, 'refresh': refresh, 'expiresAt': expiresAt.toUtc().toIso8601String()}),
  );
}
