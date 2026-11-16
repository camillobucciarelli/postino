/// The closed list of Impostazioni di Postino that sync (ADR 0004, 0015, 0016, 0019), by key prefix.
/// Everything else, and every Impostazione del dispositivo, stays on the device.
const syncedSettingPrefixes = ['auto_labels/', 'swipe/', accountsSettingPrefix, ..._passwordCredentialPrefixes];

/// The prefix of the voci `accounts/<accountId>`: one per Account collegato.
const accountsSettingPrefix = 'accounts/';

/// The prefix of the voci of the credentials of an Account (ADR 0019).
const credentialsSettingPrefix = 'credentials/';

/// The voci `credentials/<accountId>` of iCloud and IMAP: password and servers, only inside the sealed file (#321).
/// The per-client OAuth voci of Gmail and Microsoft join with their slice; until then a newer Postino's stay in the
/// file and never come here.
const _passwordCredentialPrefixes = ['${credentialsSettingPrefix}icloud:', '${credentialsSettingPrefix}imap:'];

/// The prefixes whose voci belong to one Account (`<prefix><accountId>`); the others are the same for all of them.
const accountSettingPrefixes = ['auto_labels/', accountsSettingPrefix];

/// Whether the voce [key] belongs in the synced file.
bool isSyncedSetting(String key) => syncedSettingPrefixes.any(key.startsWith);

/// Whether [key] is the voce of the password and servers of an iCloud or IMAP Account.
bool isPasswordCredentialSetting(String key) => _passwordCredentialPrefixes.any(key.startsWith);

/// The keys of the voci that belong to [accountId]: removing the Account writes their tombstones.
List<String> accountSettingKeys(String accountId) => [
  for (final p in accountSettingPrefixes) '$p$accountId',
  if (isPasswordCredentialSetting('$credentialsSettingPrefix$accountId')) '$credentialsSettingPrefix$accountId',
];
