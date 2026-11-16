import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/account.dart';
import '../../domain/synced_settings.dart';
import '../attachment_crypto.dart';
import '../gmail/google_client.dart';
import '../microsoft/microsoft_client.dart';

/// The value of the voce `credentials/<accountId>/<client>` of a Gmail or Microsoft Account (ADR 0019): the refresh
/// token one OAuth client issued, and its scopes. Never the access token: each device gets its own.
class const OAuthVoce({required final String refresh, required final List<String> scopes}) {
  /// The voce [encode] wrote; throws on anything else. Its errors may quote [raw]: never log them.
  static OAuthVoce decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return OAuthVoce(
      refresh: j['refresh'] as String,
      scopes: [for (final s in j['scopes'] as List<dynamic>) s as String],
    );
  }

  /// `{"refresh":"…","scopes":[…]}`, the scopes sorted: the same token always gives the same text.
  String encode() => jsonEncode({
    'refresh': refresh,
    'scopes': [...scopes]..sort(),
  });

  /// Whether [scopes] give strictly fewer APIs than [other] (the Gmail scope without `drive.appdata`, say): such a
  /// token never replaces the other one. The scopes that only name the user, and how a Provider spells them (a
  /// consent's `email`, a refresh's none; Graph's prefix), are left out.
  bool narrowerThan(List<String> other) {
    final mine = _apis(scopes);
    final theirs = _apis(other);
    return theirs.containsAll(mine) && theirs.length > mine.length;
  }

  static Set<String> _apis(List<String> scopes) => {
    for (final s in scopes)
      if (s.toLowerCase().replaceFirst('https://graph.microsoft.com/', '') case final api
          when !_identity.contains(api) && !api.contains('userinfo'))
        api,
  };

  static const _identity = {'', 'openid', 'email', 'profile', 'offline_access'};

  /// Never the token: it must not end up in logs.
  @override
  String toString() => 'OAuthVoce';
}

/// The OAuth client of this build for [provider]: its ID, empty when the build has none or the Provider uses a
/// password.
String oauthClientIdOf(ProviderKind provider) => switch (provider) {
  ProviderKind.gmail => const GoogleClient.fromEnvironment().id,
  ProviderKind.microsoft => const MicrosoftClient.fromEnvironment().id,
  ProviderKind.icloud || ProviderKind.imap => '',
};

/// The key of the voce of [accountId] for the OAuth client [clientId]: a fingerprint of the ID, never the ID.
String oauthCredentialsKey(String accountId, String clientId) =>
    '${credentialsKey(accountId)}/${hex(sha256.convert(utf8.encode('postino-oauth-client|$clientId')).bytes).substring(0, 16)}';

/// The keychain item that keeps the voce [voceKey] of another OAuth client, which this device never uses: only to
/// write the file again without losing it.
String oauthVoceKeychainKey(String voceKey) => 'oauth:${voceKey.substring(credentialsSettingPrefix.length)}';
