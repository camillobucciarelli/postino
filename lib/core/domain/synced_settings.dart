/// The closed list of Impostazioni di Postino that sync (ADR 0004, 0015, 0016, 0019), by key prefix.
/// Everything else, and every Impostazione del dispositivo, stays on the device.
/// The voci of credentials join by their own rule ([isCredentialSetting]).
const syncedSettingPrefixes = ['auto_labels/', 'swipe/', accountsSettingPrefix];

/// The prefix of the voci `accounts/<accountId>`: one per Account collegato.
const accountsSettingPrefix = 'accounts/';

/// The prefix of the voci of the credentials of an Account (ADR 0019).
const credentialsSettingPrefix = 'credentials/';

/// The voci `credentials/<accountId>` of iCloud and IMAP: password and servers, only inside the sealed file (#321).
const _passwordCredentialPrefixes = ['${credentialsSettingPrefix}icloud:', '${credentialsSettingPrefix}imap:'];

/// The voci `credentials/<accountId>/<client>` of Gmail and Microsoft: a refresh token per OAuth client (#321).
const _oauthCredentialPrefixes = ['${credentialsSettingPrefix}gmail:', '${credentialsSettingPrefix}microsoft:'];

/// The prefixes whose voci belong to one Account (`<prefix><accountId>`); the others are the same for all of them.
const accountSettingPrefixes = ['auto_labels/', accountsSettingPrefix];

/// Whether the voce [key] belongs in the synced file.
bool isSyncedSetting(String key) => syncedSettingPrefixes.any(key.startsWith) || isCredentialSetting(key);

/// Whether [key] is the voce of the password and servers of an iCloud or IMAP Account.
bool isPasswordCredentialSetting(String key) => _passwordCredentialPrefixes.any(key.startsWith);

/// Whether [key] is the voce of a Gmail or Microsoft Account for one OAuth client; one without a client is not.
bool isOAuthCredentialSetting(String key) =>
    _oauthCredentialPrefixes.any(key.startsWith) && key.lastIndexOf('/') > credentialsSettingPrefix.length;

/// Whether [key] is a voce of credentials this Postino syncs.
bool isCredentialSetting(String key) => isPasswordCredentialSetting(key) || isOAuthCredentialSetting(key);

/// The Account of the voce of credentials [key].
String credentialAccountId(String key) {
  final rest = key.substring(credentialsSettingPrefix.length);
  return isOAuthCredentialSetting(key) ? rest.substring(0, rest.lastIndexOf('/')) : rest;
}

/// The key of the voce of the password and servers of [accountId], and the prefix of its OAuth ones (ADR 0019).
String credentialsKey(String accountId) => '$credentialsSettingPrefix$accountId';

/// The keys of the voci that belong to [accountId]: removing the Account writes their tombstones.
List<String> accountSettingKeys(String accountId) => [
  for (final p in accountSettingPrefixes) '$p$accountId',
  if (isPasswordCredentialSetting(credentialsKey(accountId))) credentialsKey(accountId),
];
