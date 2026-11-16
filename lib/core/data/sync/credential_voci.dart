import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/account.dart';
import '../../domain/platform_services.dart';
import '../../domain/settings_entry.dart';
import '../../domain/synced_settings.dart';
import '../accounts_lock.dart';
import '../attachment_crypto.dart';
import '../imap/password_credentials.dart';
import '../postino_database.dart';

/// What the row of `postino_settings` keeps for the secret [raw]: a fingerprint, never the secret. Unkeyed: the
/// database is encrypted with a key that never leaves the device (ADR 0017), on the device that holds the secret.
String credentialFingerprint(String raw) =>
    jsonEncode({'fingerprint': hex(sha256.convert(utf8.encode('postino-credential|$raw')).bytes)});

/// Writes here the voce of the credentials [raw] of [accountId], to upload, unless it already says the same:
/// a connection with the password just checked, right after the keychain and under the AccountsLock.
Future<void> writeCredentialVoce(PostinoDatabase db, String accountId, String raw, {required DateTime at}) async {
  final key = credentialsKey(accountId);
  final fingerprint = credentialFingerprint(raw);
  if (await db.postinoSettingsDao.read(key) != fingerprint) await db.postinoSettingsDao.write(key, fingerprint, at: at);
}

/// The voci with fingerprints in place of the secrets; the secrets by key; the remote voci of credentials this
/// Postino cannot read, set aside as they are.
typedef HiddenCredentials = ({
  Map<String, SettingsEntry> entries,
  Map<String, String> secrets,
  Map<String, SettingsEntry> unread,
});

/// The voci for the sealed file, and the keys of the ones held back, to keep dirty.
typedef SealedCredentials = ({List<SettingsEntry> entries, Set<String> withheld});

/// The voci `credentials/<accountId>` of iCloud and IMAP at the two edges of a cycle (ADR 0019): after the file is
/// opened the secrets go to the keychain and the voci keep their fingerprints, so merge, applyRemote and markClean see
/// fingerprints like any other voce; before it is sealed the fingerprints turn back into the secrets.
class CredentialVoci(final PostinoDatabase _db, final SecureStore _keychain, final AccountsLock _lock) {
  /// [remote] with a fingerprint in place of each secret. A voce that is not password and servers (a newer
  /// Postino's shape) is set aside: it never reaches the database, nor a log (its parse error may quote it), and goes
  /// back into the file unchanged.
  static HiddenCredentials hide(Map<String, SettingsEntry> remote) {
    final secrets = <String, String>{};
    final entries = <String, SettingsEntry>{};
    final unread = <String, SettingsEntry>{};
    for (final e in remote.values) {
      if (isPasswordCredentialSetting(e.key) && !e.deleted) {
        try {
          PasswordCredentials.decode(e.value!);
        } on Object {
          unread[e.key] = e;
          continue;
        }
        secrets[e.key] = e.value!;
        entries[e.key] = SettingsEntry(
          key: e.key,
          value: credentialFingerprint(e.value!),
          updatedAt: e.updatedAt,
          deviceId: e.deviceId,
        );
      } else {
        entries[e.key] = e;
      }
    }
    return (entries: entries, secrets: secrets, unread: unread);
  }

  /// The voce of each attivo iCloud or IMAP Account connected before its credentials synced, as a voce written before
  /// the sync: a copy from another device wins over it.
  Future<void> backfill() async {
    for (final a in await _db.accountsDao.byPosition()) {
      final key = credentialsKey(a.id);
      if (a.status != AccountStatus.attivo || !isPasswordCredentialSetting(key)) continue;
      if (await _db.postinoSettingsDao.entry(key) != null) continue;
      final String? raw;
      try {
        raw = await _keychain.read(PasswordCredentials.keychainKey(a.id));
      } on Object {
        // A locked keychain never stops the rest of the Impostazioni: the next cycle tries again.
        continue;
      }
      if (raw != null) await _db.postinoSettingsDao.writeBeforeSync(key, credentialFingerprint(raw));
    }
  }

  /// Takes the remote voci of credentials that won the merge: the secret to the keychain first (a crash in between
  /// takes it again next cycle), then the fingerprint. Under the AccountsLock, so a connection here in between is never
  /// overwritten and the AccountsSettingsMirror sees the credential with the Account. A tombstone forgets the secret.
  /// An Account here da ricollegare turns attivo, and the mail sync tries the credential: a refusal makes it da
  /// ricollegare again, and the voce, unchanged, never brings it back. One still missing here finds the credential
  /// in the keychain once its voce `accounts/` comes, removed it never gets one.
  Future<void> arrive(Iterable<SettingsEntry> won, Map<String, String> secrets, Map<String, SettingsEntry> merged) =>
      _lock.run(() async {
        for (final e in won) {
          // Written here since the cycle read the voci: that one wins, and its secret is the one in the keychain.
          if (await _db.postinoSettingsDao.entry(e.key) case final here? when here.winsOver(e)) continue;
          final id = e.key.substring(credentialsSettingPrefix.length);
          final live = !e.deleted && !_removed(merged, id);
          if (e.deleted) {
            await PasswordCredentials.delete(_keychain, id);
          } else if (live) {
            await _keychain.write(PasswordCredentials.keychainKey(id), secrets[e.key]!);
          }
          // Together: a crash in between never leaves the fingerprint taken and the Account still da ricollegare.
          await _db.transaction(() async {
            await _db.postinoSettingsDao.applyRemote([e]);
            if (!live) return;
            final account = (await _db.accountsDao.byPosition()).where((r) => r.id == id).firstOrNull;
            if (account?.status == AccountStatus.daRicollegare) {
              await _db.accountsDao.setStatus(id, AccountStatus.attivo);
            }
          });
        }
      });

  /// The voci of [merged] for the sealed file, each fingerprint back to its secret: the remote one or the keychain's,
  /// whichever has it. When neither does (the keychain changed meanwhile) the copy already in the file, if any, stays
  /// and the voce is withheld. The credential of an Account with a tombstone goes as a tombstone, so a password
  /// written after the removal (a fetta 1 Postino, a reconnection racing it) never stays in the file. The [hidden]
  /// voci set aside go back unchanged.
  Future<SealedCredentials> seal(
    Map<String, SettingsEntry> merged,
    HiddenCredentials hidden,
    Map<String, SettingsEntry> remote,
  ) async {
    final entries = <SettingsEntry>[];
    final withheld = <String>{};
    for (final e in merged.values) {
      if (!isPasswordCredentialSetting(e.key) || e.deleted) {
        entries.add(e);
      } else if (_removed(merged, e.key.substring(credentialsSettingPrefix.length))) {
        entries.add(
          SettingsEntry(key: e.key, value: null, updatedAt: e.updatedAt, deviceId: e.deviceId, deleted: true),
        );
      } else if (await _reveal(e, hidden.secrets) case final secret?) {
        entries.add(SettingsEntry(key: e.key, value: secret, updatedAt: e.updatedAt, deviceId: e.deviceId));
      } else {
        withheld.add(e.key);
        if (remote[e.key] case final old?) entries.add(old);
      }
    }
    for (final e in hidden.unread.values) {
      if (!merged.containsKey(e.key)) entries.add(e);
    }
    return (entries: entries, withheld: withheld);
  }

  static bool _removed(Map<String, SettingsEntry> merged, String accountId) =>
      merged['$accountsSettingPrefix$accountId']?.deleted ?? false;

  Future<String?> _reveal(SettingsEntry e, Map<String, String> secrets) async {
    if (secrets[e.key] case final remote? when credentialFingerprint(remote) == e.value) return remote;
    final here = await _keychain.read(
      PasswordCredentials.keychainKey(e.key.substring(credentialsSettingPrefix.length)),
    );
    return here != null && credentialFingerprint(here) == e.value ? here : null;
  }
}
