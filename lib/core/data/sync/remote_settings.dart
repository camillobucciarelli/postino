import '../../domain/result.dart';
import '../../domain/settings_document.dart';
import '../../domain/settings_entry.dart';
import '../../domain/settings_merge.dart';
import 'settings_envelope.dart';
import 'sync_key.dart';

/// What the file on Drive is for this device and its key (ADR 0019): the states of the table «Stati di un dispositivo».
sealed class const RemoteSettings() {
  /// Costruttore delle varianti.
  this;
}

/// No file yet.
final class const NoRemoteFile() extends RemoteSettings {
  /// Crea lo stato.
  this;
}

/// A file this device reads: [doc] is what it brings.
final class const ReadableRemote(
  /// The voci to merge: the copies opened with the key, merged; none for a file in clear on a device with a key.
  final SettingsDocument doc, {

  /// Opened with the key; false for a file in clear (the first migration, or a downgrade that is overwritten).
  required final bool opened,

  /// Other copies of the file, merged in [doc] or sealed with another key: to drop once [doc] is written.
  final bool duplicates = false,
}) extends RemoteSettings {
  /// Crea lo stato.
  this;
}

/// Sealed with a key this device does not hold: Non abbinato without a key, else Chiave non più valida.
final class const LockedRemote() extends RemoteSettings {
  /// Crea lo stato.
  this;
}

/// A file never overwritten: damaged, tampered, from a newer Postino ([newer]), or in clear where none is legitimate.
final class const UnreadableRemote(
  /// Why, for the outcome of the cycle: never the key nor the content.
  final Failure failure, {

  /// From a newer Postino: only an update reads it.
  final bool newer = false,
}) extends RemoteSettings {
  /// Crea lo stato.
  this;
}

/// Reads the [copies] of the file, oldest first, with [key] (null without one). The oldest is the file. The others,
/// from two devices that created it at once, are merged into it when they open with the key, and dropped when they are
/// sealed with another key (the loser of that race asks to be paired) or in clear on a device with a key; a copy that
/// cannot be read leaves every copy alone, as before the encryption. Without a key, any sealed copy locks the file:
/// a key is made only when the file is absent or in clear.
RemoteSettings readRemoteSettings(List<String> copies, SyncKey? key) {
  if (copies.isEmpty) return const NoRemoteFile();
  // Without a key, a sealed copy anywhere means another device encrypted first: never a key of our own over it.
  if (key == null && copies.any((c) => openSettings(c, null) is LockedCopy)) return const LockedRemote();
  final first = _copy(copies.first, key);
  if (first is! ReadableRemote || !first.doc.writable || copies.length == 1) return first;
  var entries = first.doc.entries;
  var opened = first.opened;
  for (final c in copies.skip(1)) {
    switch (_copy(c, key)) {
      case ReadableRemote(:final doc, opened: final o) when doc.writable:
        entries = mergeSettings(entries, doc.entries);
        // One copy opened with the key is enough to call the key that of the file (the pairing checks it).
        opened |= o;
      case LockedRemote():
        break;
      case _:
        return first;
    }
  }
  return ReadableRemote(
    SettingsDocument(schemaVersion: first.doc.schemaVersion, entries: entries),
    opened: opened,
    duplicates: true,
  );
}

RemoteSettings _copy(String text, SyncKey? key) => switch (openSettings(text, key)) {
  OpenedCopy(:final json) => switch (decodeSettings(json)) {
    Ok(value: final doc) => ReadableRemote(doc, opened: true),
    Err(:final failure) => UnreadableRemote(failure),
  },
  // A device with a key never trusts a file in clear: a downgrade, maybe by whoever controls Drive. Nothing of it is
  // applied, and the sealed copy overwrites it.
  PlainCopy() when key != null => ReadableRemote(
    SettingsDocument(schemaVersion: settingsSchemaVersion, entries: const {}),
    opened: false,
  ),
  PlainCopy(:final json) => _plain(json),
  LockedCopy() => const LockedRemote(),
  UnreadableCopy(:final reason, :final newer) => UnreadableRemote(UnexpectedFailure(reason), newer: newer),
};

/// The first migration: a file in clear is accepted only from the versions that wrote it so (schema at most
/// [lastPlainSchemaVersion]), and never with its `credentials/` voci, which no such file can hold legitimately.
RemoteSettings _plain(String json) => switch (decodeSettings(json)) {
  Ok(value: final doc) when doc.schemaVersion <= lastPlainSchemaVersion => ReadableRemote(
    SettingsDocument(
      schemaVersion: doc.schemaVersion,
      entries: <String, SettingsEntry>{
        for (final e in doc.entries.entries)
          if (!e.key.startsWith('credentials/')) e.key: e.value,
      },
    ),
    opened: false,
  ),
  Ok() => const UnreadableRemote(UnexpectedFailure('file in clear above schema 2')),
  Err(:final failure) => UnreadableRemote(failure),
};
