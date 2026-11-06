import '../domain/platform_services.dart';
import 'gmail/gmail_tokens.dart';
import 'imap/password_credentials.dart';

/// Forgets every credential of [accountId] in the keychain, whatever its Provider: the OAuth tokens of Gmail, the
/// password and servers of iCloud and IMAP. The Account was removed (ADR 0016).
// ponytail: both keys for every Account, a missing one is a no-op; a factory per Provider if one ever keeps more.
Future<void> deleteCredentials(SecureStore keychain, String accountId) async {
  await GmailTokens.delete(keychain, accountId);
  await PasswordCredentials.delete(keychain, accountId);
}
