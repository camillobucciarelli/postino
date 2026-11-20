import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/account.dart';
import '../../domain/platform_services.dart';
import '../../domain/settings_entry.dart';
import '../../domain/synced_settings.dart';
import '../accounts_lock.dart';
import '../attachment_crypto.dart';
import '../imap/password_credentials.dart';
import '../oauth/oauth_tokens.dart';
import '../oauth/oauth_voce.dart';
import '../postino_database.dart';

/// What the row of `postino_settings` keeps for the secret [raw]: a fingerprint, never the secret. Unkeyed: the
/// database is encrypted with a key that never leaves the device (ADR 0017), on the device that holds the secret.
String credentialFingerprint(String raw) =>
    jsonEncode({'fingerprint': hex(sha256.convert(utf8.encode('postino-credential|$raw')).bytes)});

/// Writes here the voce [key] of the credentials [raw], to upload, unless it already says the same: a connection
/// with the credentials just checked, right after the keychain and under the AccountsLock.
Future<void> writeCredentialVoce(PostinoDatabase db, String key, String raw, {required DateTime at}) async {
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

/// The voci of credentials at the two edges of a cycle (ADR 0019): `credentials/<accountId>` of iCloud and IMAP,
/// `credentials/<accountId>/<client>` of Gmail and Microsoft. After the file is opened the secrets go to the keychain
/// and the voci keep their fingerprints, so merge, applyRemote and markClean see fingerprints like any other voce;
/// before it is sealed the fingerprints turn back into the secrets.
///
/// The voce of this device's OAuth client is its tokens in use (`oauth:<accountId>`): its refresh token and scopes.
/// The voci of the other clients wait in the keychain (`oauth:<accountId>/<client>`), never used here.
class CredentialVoci(
  final PostinoDatabase _db,
  final SecureStore _keychain,
  final AccountsLock _lock,
  final Clock _clock, {
  final String Function(ProviderKind) _clientOf = oauthClientIdOf,
}) {
  /// [remote] with a fingerprint in place of each secret. A voce not in the shape this Postino writes (a newer
  /// Postino's) is set aside: it never reaches the database, nor a log (its parse error may quote it), and goes back
  /// into the file unchanged.
  static HiddenCredentials hide(Map<String, SettingsEntry> remote) {
    final secrets = <String, String>{};
    final entries = <String, SettingsEntry>{};
    final unread = <String, SettingsEntry>{};
    for (final e in remote.values) {
      if (isCredentialSetting(e.key) && !e.deleted) {
        try {
          isOAuthCredentialSetting(e.key) ? OAuthVoce.decode(e.value!) : PasswordCredentials.decode(e.value!);
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

  /// The voce of each attivo Account from the keychain here. One connected before its credentials synced gets it as
  /// a voce written before the sync: a copy from another device wins over it. The voce of this device's OAuth client
  /// follows its tokens in use: a refresh token rotated (Microsoft), or one kept here over a remote one with fewer
  /// scopes, is written now, so the others take it. Tokens whose scopes are not known yet wait for their refresh.
  Future<void> backfill() => _lock.run(() async {
    for (final a in await _db.accountsDao.byPosition()) {
      final key = isPasswordCredentialSetting(credentialsKey(a.id)) ? credentialsKey(a.id) : _ownKey(a.id);
      if (a.status != AccountStatus.attivo || key == null) continue;
      final String? raw;
      try {
        raw = await _secretHere(key);
      } on Object {
        // A locked keychain never stops the rest of the Impostazioni: the next cycle tries again.
        continue;
      }
      if (raw == null) continue;
      final fingerprint = credentialFingerprint(raw);
      switch (await _db.postinoSettingsDao.entry(key)) {
        case null:
          await _db.postinoSettingsDao.writeBeforeSync(key, fingerprint);
        case final here when isOAuthCredentialSetting(key) && !here.deleted && here.value != fingerprint:
          await _db.postinoSettingsDao.write(key, fingerprint, at: _clock.now());
        case _:
      }
    }
  });

  /// Takes the remote voci of credentials that won the merge: the secret to the keychain first (a crash in between
  /// takes it again next cycle), then the fingerprint. Under the AccountsLock, so a connection here in between is never
  /// overwritten and the AccountsSettingsMirror sees the credential with the Account. A tombstone forgets the secret.
  /// An Account here da ricollegare turns attivo when the voce is its credential, and the mail sync tries it: a
  /// refusal makes it da ricollegare again, and the voce, unchanged, never brings it back. One still missing here
  /// finds the credential in the keychain once its voce `accounts/` comes, removed it never gets one.
  Future<void> arrive(Iterable<SettingsEntry> won, Map<String, String> secrets, Map<String, SettingsEntry> merged) =>
      _lock.run(() async {
        for (final e in won) {
          // Written here since the cycle read the voci: that one wins, and its secret is the one in the keychain.
          if (await _db.postinoSettingsDao.entry(e.key) case final here? when here.winsOver(e)) continue;
          final id = credentialAccountId(e.key);
          // Held back by the tombstone of its Account: not taken, so it arrives once the Account is back.
          if (!e.deleted && _removed(merged, id)) continue;
          final taken = await _take(e, id, secrets[e.key]);
          // Together: a crash in between never leaves the fingerprint taken and the Account still da ricollegare.
          await _db.transaction(() async {
            await _db.postinoSettingsDao.applyRemote([e]);
            if (taken && await _status(id) == AccountStatus.daRicollegare) {
              await _db.accountsDao.setStatus(id, AccountStatus.attivo);
            }
          });
        }
      });

  /// The voci of [merged] for the sealed file, each fingerprint back to its secret: the remote one or the keychain's,
  /// whichever has it. When neither does (the keychain changed meanwhile) the copy already in the file, if any, stays
  /// and the voce is withheld. The credential of an Account with a tombstone goes as a tombstone, so a secret
  /// written after the removal (an older Postino, a reconnection racing it) never stays in the file. The [hidden]
  /// voci set aside go back unchanged when [merged] has no voce for them (the cycle leaves out the older copies here).
  Future<SealedCredentials> seal(
    Map<String, SettingsEntry> merged,
    HiddenCredentials hidden,
    Map<String, SettingsEntry> remote,
  ) async {
    final entries = <SettingsEntry>[];
    final withheld = <String>{};
    for (final e in merged.values) {
      if (!isCredentialSetting(e.key) || e.deleted) {
        entries.add(e);
      } else if (_removed(merged, credentialAccountId(e.key))) {
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

  /// Puts the secret of [e] in the keychain; whether it is now the credential the Account [id] uses here.
  Future<bool> _take(SettingsEntry e, String id, String? secret) async {
    if (isPasswordCredentialSetting(e.key)) {
      if (e.deleted) {
        await PasswordCredentials.delete(_keychain, id);
        return false;
      }
      await _keychain.write(PasswordCredentials.keychainKey(id), secret!);
      return true;
    }
    if (e.key != _ownKey(id)) {
      final item = oauthVoceKeychainKey(e.key);
      await (e.deleted ? _keychain.delete(item) : _keychain.write(item, secret!));
      return false;
    }
    // The tokens in use go with the Account, when the mirror removes it; without the Account here no mirror will,
    // as with tokens that came before it.
    if (e.deleted) {
      if (await _status(id) == null) await OAuthTokens.delete(_keychain, id);
      return false;
    }
    return _adopt(id, OAuthVoce.decode(secret!));
  }

  /// Makes [voce] the tokens in use of [id], keeping the access token here: a valid one is no reason to refresh
  /// (which for Microsoft would rotate the token and write the voce again). Not over a token here, while the
  /// Provider takes it, with more scopes (Drive, ADR 0019) or with scopes not known yet: the next cycle writes it.
  Future<bool> _adopt(String id, OAuthVoce voce) async {
    final here = await OAuthTokens.read(_keychain, id);
    if (here != null && await _status(id) == AccountStatus.attivo) {
      if (here.scopes.isEmpty || voce.narrowerThan(here.scopes)) return false;
    }
    await OAuthTokens(
      access: here?.access ?? '',
      refresh: voce.refresh,
      expiresAt: here?.expiresAt ?? DateTime.utc(1970),
      scopes: voce.scopes,
      synced: true,
    ).write(_keychain, id);
    return true;
  }

  Future<AccountStatus?> _status(String id) async =>
      (await _db.accountsDao.byPosition()).where((r) => r.id == id).firstOrNull?.status;

  /// The key of the voce of [accountId] for this device's OAuth client; null for a password Account, or a build
  /// without that client.
  String? _ownKey(String accountId) {
    final provider = ProviderKind.values.asNameMap()[accountId.split(':').first];
    final client = provider == null ? '' : _clientOf(provider);
    return client.isEmpty ? null : oauthCredentialsKey(accountId, client);
  }

  static bool _removed(Map<String, SettingsEntry> merged, String accountId) =>
      merged['$accountsSettingPrefix$accountId']?.deleted ?? false;

  Future<String?> _reveal(SettingsEntry e, Map<String, String> secrets) async {
    if (secrets[e.key] case final remote? when credentialFingerprint(remote) == e.value) return remote;
    final String? here;
    try {
      here = await _secretHere(e.key);
    } on Object {
      // A locked keychain is a secret not available: the copy in the file stays, the voce waits.
      return null;
    }
    return here != null && credentialFingerprint(here) == e.value ? here : null;
  }

  /// The secret of the voce [key] in the keychain here; for this device's OAuth client, from its tokens in use.
  Future<String?> _secretHere(String key) async {
    final id = credentialAccountId(key);
    if (isPasswordCredentialSetting(key)) return _keychain.read(PasswordCredentials.keychainKey(id));
    if (key != _ownKey(id)) return _keychain.read(oauthVoceKeychainKey(key));
    final tokens = await OAuthTokens.read(_keychain, id);
    return tokens == null || tokens.scopes.isEmpty
        ? null
        : OAuthVoce(refresh: tokens.refresh, scopes: tokens.scopes).encode();
  }
}
