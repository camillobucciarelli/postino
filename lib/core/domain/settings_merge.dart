import 'settings_entry.dart';

/// Last-write-wins per voce (ADR 0016): for each key the copy that [SettingsEntry.winsOver] the other.
/// Tombstones take part like any voce, so an older copy never brings a removed voce back.
Map<String, SettingsEntry> mergeSettings(Map<String, SettingsEntry> a, Map<String, SettingsEntry> b) => {
  ...a,
  for (final e in b.values)
    if (a[e.key] == null || e.winsOver(a[e.key]!)) e.key: e,
};
