/// The closed list of Impostazioni di Postino that sync (ADR 0004, 0015, 0016), by key prefix.
/// Everything else, and every Impostazione del dispositivo, stays on the device.
const syncedSettingPrefixes = ['auto_labels/', 'swipe/', accountsSettingPrefix];

/// The prefix of the voci `accounts/<accountId>`: one per Account collegato.
const accountsSettingPrefix = 'accounts/';

/// The prefixes whose voci belong to one Account (`<prefix><accountId>`); the others are the same for all of them.
const accountSettingPrefixes = ['auto_labels/', accountsSettingPrefix];

/// Whether the voce [key] belongs in the synced file.
bool isSyncedSetting(String key) => syncedSettingPrefixes.any(key.startsWith);

/// The keys of the voci that belong to [accountId]: removing the Account writes their tombstones.
List<String> accountSettingKeys(String accountId) => [for (final p in accountSettingPrefixes) '$p$accountId'];
