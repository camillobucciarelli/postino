import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/accounts_repository.dart';
import '../domain/attachment_repository.dart';
import '../domain/connection_tester.dart';
import '../domain/google_consent.dart';
import '../domain/mail_servers.dart';
import '../domain/microsoft_consent.dart';
import '../domain/oauth_grant.dart';
import '../domain/password_provider.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';
import '../domain/server_discovery.dart';
import '../domain/settings_repository.dart';
import 'account_settings_json.dart';
import 'accounts_lock.dart';
import 'gmail/google_revoke.dart';
import 'imap/password_credentials.dart';
import 'mail_store.dart';
import 'oauth/oauth_tokens.dart';
import 'postino_database.dart';
import 'settings_sync.dart';
import 'sync/credential_voci.dart';
import 'sync_engine.dart';

/// How long the removal of the Account di sincronizzazione waits for its tombstones to reach Drive.
const _uploadWait = Duration(seconds: 15);

@LazySingleton(as: AccountsRepository)
class AccountsService(
  final MailStore _store,
  final GoogleConsent _consent,
  final MicrosoftConsent _microsoft,
  final SecureStore _keychain,
  final SyncEngine _sync,
  final PostinoDatabase _db,
  final Clock _clock,
  final SettingsRepository _settings,
  final AccountsLock _lock,
  final ServerDiscovery _discovery,
  final ConnectionTester _tester,
  final GoogleRevoke _revoke,
  final AttachmentRepository _attachments,
  final SettingsSync _settingsSync,
) implements AccountsRepository {
  @override
  Stream<List<Account>> watchAccounts() => _store.watchAccounts();

  @override
  Future<Result<Account>> connectGmail({String? loginHint}) =>
      _connectOAuth(ProviderKind.gmail, loginHint, () => _consent.run(loginHint: loginHint));

  @override
  Future<Result<Account>> connectMicrosoft({String? loginHint}) =>
      _connectOAuth(ProviderKind.microsoft, loginHint, () => _microsoft.run(loginHint: loginHint));

  /// The consent of an OAuth Provider, then the Account it names.
  Future<Result<Account>> _connectOAuth(
    ProviderKind provider,
    String? loginHint,
    Future<Result<OAuthGrant>> Function() consent,
  ) async {
    // The revocation of a removal still running ends the whole grant at Google (#174), a newer one too: the consent
    // waits for it. Which Account the grant is for is known only afterwards, so it waits for every removal.
    await Future.wait([for (final r in _removals.values) r.catchError((Object _) {})]);
    // ponytail: not a `final grant;` assigned in a switch: captured by the lock's closure below, it crashes the AOT
    // compiler of Dart 3.14 (linearscan.cc, `flutter build ios`).
    final consented = await consent();
    if (consented case Err(:final failure)) return Err(failure);
    final grant = (consented as Ok<OAuthGrant>).value;
    if (loginHint != null && normalizedAddress(loginHint) != normalizedAddress(grant.address)) {
      return Err(WrongAccountFailure(loginHint));
    }
    // Addresses are case-insensitive: normalized once, so id and stored address agree for onboarding and every reconnection.
    final address = normalizedAddress(grant.address);
    final id = accountIdOf(provider, address);
    // Removed while the user was on the Provider's page: its revocation would end this grant too, so the consent is
    // to run again once it is over.
    if (_removals[id] case final removing?) {
      await removing.catchError((Object _) {});
      return const Err(CancelledFailure());
    }
    final removals = _removalsStarted[id];
    // Under the lock: a removal of the same Account from another device in flight never deletes these credentials.
    final account = await _lock.run(() async {
      // Removed here while waiting for the lock: as above.
      if (_removalsStarted[id] != removals) return null;
      await OAuthTokens.of(grant).write(_keychain, id);
      return _save(id, address, provider);
    });
    if (account == null) return const Err(CancelledFailure());
    unawaited(_sync.syncAll());
    return Ok(account);
  }

  @override
  Future<Result<Account>> connectWithPassword(
    String address,
    String password, {
    ServerSettings? servers,
    Future<void>? cancel,
  }) async {
    var cancelled = false;
    unawaited(cancel?.then((_) => cancelled = true));
    final normalized = normalizedAddress(address);
    // An IMAP Account saved before the Microsoft button (an Outlook.com address) still reconnects with its password.
    final legacy = (await _store.accounts()).any((a) => a.id == accountIdOf(ProviderKind.imap, normalized));
    final provider = passwordProviderFor(normalized) ?? (legacy ? const PasswordProvider(ProviderKind.imap) : null);
    if (provider == null) {
      return Err(
        oauthProviderFor(normalized) == ProviderKind.microsoft ? const UseMicrosoftFailure() : const UseGmailFailure(),
      );
    }
    final id = accountIdOf(provider.kind, normalized);
    final known = (await _store.accounts()).where((a) => a.id == id).firstOrNull;
    // The same address through another Provider is another Account (ADR 0016): only this one, attivo, is refused.
    if (known?.status == AccountStatus.attivo) return const Err(AlreadyConnectedFailure());
    // A reconnection keeps the servers the Account was saved with, here or in the credentials from another device
    // (ADR 0019); an Account arrived without them has none, so the preset or the discovery finds them.
    final saved = known == null ? null : (await PasswordCredentials.read(_keychain, id))?.servers;
    final chosen = servers ?? saved ?? provider.preset ?? await _discovery.discover(normalized);
    if (chosen == null) return const Err(ServerNotFoundFailure());
    // A Microsoft 365 address (a custom domain hosted there) never logs in with a password; a legacy Account keeps
    // what it was saved with.
    if (!legacy && microsoft365Servers(chosen)) return const Err(UseMicrosoftFailure());
    switch (await _tester.test(chosen, user: normalized, password: password)) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
    }
    await _removals[id]?.catchError((Object _) {});
    // The user closed the form while the servers answered, or while a removal of the same Account ended: nothing
    // is written.
    if (cancelled) return const Err(CancelledFailure());
    final removals = _removalsStarted[id];
    final account = await _lock.run(() async {
      // Closed, or the Account removed here, while waiting for the lock: still nothing written.
      if (cancelled || _removalsStarted[id] != removals) return null;
      final credentials = PasswordCredentials(password: password, servers: chosen);
      await credentials.write(_keychain, id);
      final added = await _save(id, normalized, provider.kind);
      // Stamped now even with the sync off: a password just checked wins over an older copy elsewhere (ADR 0019).
      await writeCredentialVoce(_db, id, credentials.encode(), at: _clock.now());
      return added;
    });
    if (account == null) return const Err(CancelledFailure());
    unawaited(_sync.syncAll());
    return Ok(account);
  }

  /// The Account here, attivo, and its synced voce (ADR 0016), in one transaction: the AccountsSettingsMirror sees
  /// both or neither. A known Account (da ricollegare, maybe from another device) keeps color and position, and its
  /// voce is written only if it says something else, so a reconnection does not move the voce's updatedAt.
  /// With the sync off (the onboarding comes before «Sincronizza su…») a new voce is one written before the sync:
  /// the copy of another device wins over its default color and position. With the sync on it is stamped now, so
  /// an older tombstone does not remove an Account just connected on purpose.
  Future<Account> _save(String id, String address, ProviderKind provider) => _db.transaction(() async {
    final all = await _store.accounts();
    final known = all.where((a) => a.id == id).firstOrNull;
    final account = Account(
      id: id,
      address: address,
      provider: provider,
      color: known?.color ?? all.length % accountColorCount,
      // After the last one: a removal leaves a gap, never a duplicate, an Account from another device too.
      position: known?.position ?? all.fold<int>(-1, (m, a) => a.position > m ? a.position : m) + 1,
    );
    await _store.addAccount(account);
    final key = accountSettingsKey(id);
    final voce = decodeAccountSettings(id, await _db.postinoSettingsDao.read(key));
    if (voce != null && sameAccountSettings(voce, account)) return account;
    final json = encodeAccountSettings(account);
    final syncOff = await _settings.settingsSyncAccount() == null;
    if (!syncOff || !await _db.postinoSettingsDao.writeBeforeSync(key, json)) {
      await _db.postinoSettingsDao.write(key, json, at: _clock.now());
    }
    return account;
  });

  @override
  Future<Result<void>> grantDriveAccess(String accountId) async {
    final account = (await _store.accounts()).where((a) => a.id == accountId).firstOrNull;
    if (account == null) return const Err(NotFoundFailure());
    switch (await _consent.run(loginHint: account.address, drive: true)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (normalizedAddress(value.address) != account.address) return Err(WrongAccountFailure(account.address));
        // Removed while the user was on Google's page (#174), here or on another device: no tokens for it, and
        // nothing to choose. Checked again under the lock, so a removal from another device cannot run in between.
        if (_removals.containsKey(accountId)) return const Err(NotFoundFailure());
        return _lock.run(() async {
          if (!await _db.accountsDao.exists(account.id)) return const Err(NotFoundFailure());
          await OAuthTokens.of(value).write(_keychain, account.id);
          return const Ok(null);
        });
    }
  }

  /// The removals running, by Account: a connection of the same Account waits for its credential cleanup.
  final _removals = <String, Future<void>>{};

  /// How many removals of each Account started: a connection that saw no removal before waiting for the lock writes
  /// nothing if one started meanwhile.
  final _removalsStarted = <String, int>{};

  @override
  Future<void> remove(String accountId) {
    // A second «Rimuovi» of the same Account while the first runs joins it: one cleanup, one entry to wait for.
    if (_removals[accountId] case final running?) return running;
    _removalsStarted.update(accountId, (n) => n + 1, ifAbsent: () => 1);
    final run = _removals[accountId] = _remove(accountId);
    run.whenComplete(() {
      if (identical(_removals[accountId], run)) _removals.remove(accountId)?.ignore();
    }).ignore();
    return run;
  }

  Future<void> _remove(String accountId) async {
    final account = (await _store.accounts()).where((a) => a.id == accountId).firstOrNull;
    if (account == null) return;
    // First: from here nothing of the Account goes to the Provider, whatever the keychain below takes.
    await _sync.removeAccount(accountId, () => _store.removeAccount(accountId, at: _clock.now()));
    // Still there (they go last); a keychain that does not answer never blocks the removal.
    final tokens = await OAuthTokens.read(_keychain, accountId).catchError((Object _) => null);
    if (await _settings.settingsSyncAccount() == accountId) {
      // Its tombstones go up first, while its credentials are still here (ADR 0016): else the other devices never
      // see the removal. Offline or failed, they stay dirty until another Account is chosen for the sync.
      // ponytail: at most _uploadWait, so «Rimuovi» never hangs on Drive.
      await _settingsSync.syncNow().timeout(_uploadWait, onTimeout: () {});
      // The Impostazioni di Postino no longer have a Drive to sync on.
      await _settings.setSettingsSyncAccount(null);
    }
    // After the delete: a download already running for the Account finds it removed and writes nothing. A cache
    // that cannot be emptied never stops the revocation nor the keychain cleanup.
    try {
      await _attachments.clear();
    } on Object catch (e) {
      debugPrint('[accounts] $accountId: attachment cache not cleared, ${e.runtimeType}');
    }
    // Only a Google token goes to Google; Microsoft's is not revoked in v1 (the grant stays in the user's account).
    if (tokens != null && account.provider == ProviderKind.gmail) await _revoke.revoke(tokens.refresh);
    // Last, so a token refresh still running meanwhile cannot write them back; each one on its own, so a keychain
    // that refuses one never leaves the other.
    for (final delete in [OAuthTokens.delete, PasswordCredentials.delete]) {
      try {
        await delete(_keychain, accountId);
      } on Object catch (e) {
        debugPrint('[accounts] $accountId: keychain delete failed, ${e.runtimeType}');
      }
    }
  }
}
