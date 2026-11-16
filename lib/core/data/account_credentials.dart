import '../domain/platform_services.dart';
import '../domain/synced_settings.dart';
import 'imap/password_credentials.dart';
import 'oauth/oauth_tokens.dart';
import 'oauth/oauth_voce.dart';
import 'postino_database.dart';

/// The keychain items of [accountId], whatever its Provider: the OAuth tokens of Gmail and Microsoft, the password
/// and servers of iCloud and IMAP, the voci of the other OAuth clients that reached this device (ADR 0019).
// ponytail: both keys for every Account, a missing one is a no-op; a factory per Provider if one ever keeps more.
Future<List<String>> credentialItems(PostinoDatabase db, String accountId) async => [
  OAuthTokens.keychainKey(accountId),
  PasswordCredentials.keychainKey(accountId),
  for (final r in await db.postinoSettingsDao.readPrefixWithTombstones('${credentialsKey(accountId)}/'))
    oauthVoceKeychainKey(r.key),
];

/// Whether the keychain has credentials [accountId] can use here: an Account that arrives from another device with
/// them is attivo (ADR 0019).
Future<bool> hasCredentials(SecureStore keychain, String accountId) async =>
    await keychain.read(OAuthTokens.keychainKey(accountId)) != null ||
    await keychain.read(PasswordCredentials.keychainKey(accountId)) != null;

/// Forgets every credential of [accountId] in the keychain ([credentialItems]): the Account was removed (ADR 0016).
Future<void> deleteCredentials(SecureStore keychain, PostinoDatabase db, String accountId) async {
  for (final item in await credentialItems(db, accountId)) {
    await keychain.delete(item);
  }
}
