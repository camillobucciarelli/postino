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

/// The key of the voce of the password and servers of [accountId] (ADR 0019).
String credentialsKey(String accountId) => '$credentialsSettingPrefix$accountId';

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

/// The secrets of the remote voci, by key, and the voci with their fingerprints in place of the secrets.
typedef HiddenCredentials = ({Map<String, SettingsEntry> entries, Map<String, String> secrets});

/// The voci `credentials/<accountId>` of iCloud and IMAP at the two edges of a cycle (ADR 0019): after the file is
/// opened the secrets go to the keychain and the voci keep their fingerprints, so merge, applyRemote and markClean see
/// fingerprints like any other voce; before it is sealed the fingerprints turn back into the secrets.
class CredentialVoci(final PostinoDatabase _db, final SecureStore _keychain, final AccountsLock _lock) {
  /// [remote] with a fingerprint in place of each secret. A voce that is not password and servers is left out: it
  /// never reaches the database, nor a log (its parse error may quote it).
  static HiddenCredentials hide(Map<String, SettingsEntry> remote) {
    final secrets = <String, String>{};
    final entries = <String, SettingsEntry>{};
    for (final e in remote.values) {
      if (isPasswordCredentialSetting(e.key) && !e.deleted) {
        try {
          PasswordCredentials.decode(e.value!);
        } on Object {
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
    return (entries: entries, secrets: secrets);
  }

  /// The voce of each attivo iCloud or IMAP Account connected before its credentials synced, as a voce written before
  /// the sync: a copy from another device wins over it.
  Future<void> backfill() async {
    for (final a in await _db.accountsDao.byPosition()) {
      final key = credentialsKey(a.id);
      if (a.status != AccountStatus.attivo || !isPasswordCredentialSetting(key)) continue;
      if (await _db.postinoSettingsDao.entry(key) != null) continue;
      final raw = await _keychain.read(PasswordCredentials.keychainKey(a.id));
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
          if (e.deleted) {
            await PasswordCredentials.delete(_keychain, id);
          } else if (merged['$accountsSettingPrefix$id']?.deleted != true) {
            await _keychain.write(PasswordCredentials.keychainKey(id), secrets[e.key]!);
          }
          await _db.postinoSettingsDao.applyRemote([e]);
          if (!e.deleted) {
            final account = (await _db.accountsDao.byPosition()).where((r) => r.id == id).firstOrNull;
            if (account?.status == AccountStatus.daRicollegare) {
              await _db.accountsDao.setStatus(id, AccountStatus.attivo);
            }
          }
        }
      });

  /// The secret of the voce [e] for the sealed file: the remote one or the keychain's, whichever has its fingerprint.
  /// Null when neither does (the keychain changed meanwhile): the voce stays out of this write, and dirty.
  Future<String?> reveal(SettingsEntry e, Map<String, String> secrets) async {
    if (secrets[e.key] case final remote? when credentialFingerprint(remote) == e.value) return remote;
    final here = await _keychain.read(
      PasswordCredentials.keychainKey(e.key.substring(credentialsSettingPrefix.length)),
    );
    return here != null && credentialFingerprint(here) == e.value ? here : null;
  }
}
