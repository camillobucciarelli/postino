import 'settings_entry.dart';

/// Last-write-wins per voce (ADR 0016): for each key the copy that [SettingsEntry.winsOver] the other.
/// Tombstones take part like any voce, so an older copy never brings a removed voce back.
/// On an exact tie (same updatedAt and deviceId, as the voci migrated to schema 16 with different values)
/// the remote copy [b] wins, so the devices converge on what the first one uploaded instead of fighting.
Map<String, SettingsEntry> mergeSettings(Map<String, SettingsEntry> a, Map<String, SettingsEntry> b) => {
  ...a,
  for (final e in b.values)
    if (a[e.key] == null || !a[e.key]!.winsOver(e)) e.key: e,
};
