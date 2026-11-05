/// The closed list of Impostazioni di Postino that sync (ADR 0004, 0015, 0016), by key prefix.
/// Everything else, and every Impostazione del dispositivo, stays on the device.
const syncedSettingPrefixes = ['auto_labels/', accountsSettingPrefix];

/// The prefix of the voci `accounts/<accountId>`: one per Account collegato.
const accountsSettingPrefix = 'accounts/';

/// Whether the voce [key] belongs in the synced file.
bool isSyncedSetting(String key) => syncedSettingPrefixes.any(key.startsWith);

/// The keys of the voci that belong to [accountId]: removing the Account writes their tombstones.
List<String> accountSettingKeys(String accountId) => [for (final p in syncedSettingPrefixes) '$p$accountId'];
