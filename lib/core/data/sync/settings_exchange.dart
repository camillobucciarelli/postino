import '../../domain/result.dart';
import '../../domain/settings_backend.dart';
import '../../domain/settings_document.dart';
import '../../domain/settings_entry.dart';
import '../../domain/settings_merge.dart';
import '../../domain/synced_settings.dart';
import '../postino_database.dart';
import 'credential_voci.dart';
import 'remote_settings.dart';
import 'settings_envelope.dart';
import 'sync_key.dart';
import 'sync_key_store.dart';

/// One exchange with the file of the Impostazioni on Drive (ADR 0016), sealed with the Chiave di sincronizzazione
/// (ADR 0019): the backend moves only sealed text and never sees the key. `SettingsSync` runs them one at a time.
/// The credentials of iCloud and IMAP travel in it, swapped for their fingerprints here ([CredentialVoci]).
class SettingsExchange(final PostinoDatabase _db, final SyncKeyStore _keys, final CredentialVoci _credentials) {
  /// Reads the file, merges, applies here the remote copies that won, writes the file sealed if it changed and its
  /// version allows it, then marks clean what was uploaded; the [Failure] that stopped it, if one did.
  ///
  /// A key is made only when this device has none and the file is absent or in clear; a file sealed with a key not
  /// held here is neither applied nor written ([SyncNotPairedFailure], [SyncKeyInvalidFailure]). With [regenerate]
  /// («Rigenera la chiave») a new key seals it anyway: merged first when it reads, else overwritten with the voci here.
  Future<Failure?> cycle(SettingsBackend backend, {required bool regenerate}) async {
    await _credentials.backfill();
    final local = {
      for (final e in await _db.postinoSettingsDao.entries())
        if (isSyncedSetting(e.key)) e.key: e,
    };
    var key = await _keys.read();
    final List<String> copies;
    switch (await backend.read()) {
      case Err(:final failure):
        return failure;
      case Ok(:final value):
        copies = value;
    }

    var state = readRemoteSettings(copies, key);
    // A regeneration whose answer was lost (a timeout, the app killed) may have reached Drive all the same: if the
    // file opens only with the regenerated key, it becomes this device's key. Either way it is no longer pending.
    if (await _keys.readPending() case final pending?) {
      if (state is LockedRemote) {
        final withPending = readRemoteSettings(copies, pending);
        if (withPending is! LockedRemote) {
          await _keys.write(pending);
          (key, state) = (pending, withPending);
        }
      }
      await _keys.clearPending();
    }

    final SettingsDocument remote;
    var rewrite = regenerate;
    var duplicates = false;
    switch (state) {
      case ReadableRemote(:final doc, :final opened, duplicates: final d):
        remote = doc;
        rewrite |= !opened || d;
        duplicates = d;
      case NoRemoteFile():
        remote = _empty;
      // A newer Postino's file is never overwritten, not even by a new key: an update reads it.
      case UnreadableRemote(:final failure, :final newer) when !regenerate || newer:
        return failure;
      case LockedRemote() when !regenerate:
        return key == null ? const SyncNotPairedFailure() : const SyncKeyInvalidFailure();
      case UnreadableRemote() || LockedRemote():
        // What was on Drive and is not here is lost: the confirmation of «Rigenera la chiave» says so.
        remote = _empty;
    }
    // A newer Postino's file is never overwritten, not even by a new key: the regeneration fails, never seems done.
    if (regenerate && !remote.writable) return const UnexpectedFailure('file from a newer Postino: update it');

    // From here the voci of credentials hold fingerprints; their secrets are only in [secrets] and the keychain.
    final hidden = CredentialVoci.hide(remote.entries);
    final entries = hidden.entries;
    final merged = mergeSettings(local, entries);
    // Voci outside the closed list (a newer Postino's) stay in the file but never come here.
    final won = [
      for (final e in merged.values)
        if (isSyncedSetting(e.key) && local[e.key] != e) e,
    ];
    await _credentials.arrive(
      [
        for (final e in won)
          if (isPasswordCredentialSetting(e.key)) e,
      ],
      hidden.secrets,
      merged,
    );
    await _db.postinoSettingsDao.applyRemote([
      for (final e in won)
        if (!isPasswordCredentialSetting(e.key)) e,
    ]);
    // A newer Postino's file is never overwritten: the voci here stay dirty until this one is updated, and the cycle
    // is not a success while they wait (#317).
    if (!remote.writable) {
      return _same(merged, entries) ? null : const UnexpectedFailure('file from a newer Postino: update it');
    }
    var withheld = const <String>{};
    if (rewrite || !_same(merged, entries)) {
      final sealed = await _credentials.seal(merged, hidden, remote.entries);
      withheld = sealed.withheld;
      final sealWith = regenerate || key == null ? SyncKey.random() : key;
      // A first key is kept before the write: a write that fails leaves this device with the key the next cycle
      // reuses on a file still absent or in clear. A regenerated one waits as pending, and replaces the key only after
      // the write: until then the file is sealed with the old key, which this device must keep to go on reading it.
      if (regenerate) {
        await _keys.writePending(sealWith);
      } else if (key == null) {
        await _keys.write(sealWith);
      }
      if (await backend.write(sealSettings(encodeSettings(sealed.entries), sealWith)) case Err(:final failure)) {
        return failure;
      }
      if (regenerate) {
        await _keys.write(sealWith);
        await _keys.clearPending();
      }
      if (duplicates) {
        if (await backend.dropDuplicates() case Err(:final failure)) return failure;
      }
    }
    await _db.postinoSettingsDao.markClean([
      for (final e in local.values)
        if (merged[e.key] == e && !withheld.contains(e.key)) e,
    ]);
    return null;
  }

  /// Keeps [key] only once it opened the file on Drive as it is now: a [PairingCodeFailure] when it does not, a
  /// [NothingToPairFailure] when there is no sealed file, the read's failure offline. Nothing is saved on a failure.
  Future<Failure?> pair(SettingsBackend backend, SyncKey key) async {
    switch (await backend.read()) {
      case Err(:final failure):
        return failure;
      case Ok(value: final copies):
        switch (readRemoteSettings(copies, key)) {
          case ReadableRemote(opened: true):
            await _keys.write(key);
            return null;
          case NoRemoteFile() || ReadableRemote():
            return const NothingToPairFailure();
          case LockedRemote():
            return const PairingCodeFailure();
          case UnreadableRemote(:final failure):
            return failure;
        }
    }
  }

  static final _empty = SettingsDocument(schemaVersion: settingsSchemaVersion, entries: const {});

  static bool _same(Map<String, SettingsEntry> a, Map<String, SettingsEntry> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}
