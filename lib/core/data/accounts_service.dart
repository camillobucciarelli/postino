import 'dart:async';
import 'dart:math';

import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/accounts_repository.dart';
import '../domain/connection_tester.dart';
import '../domain/google_consent.dart';
import '../domain/mail_servers.dart';
import '../domain/password_provider.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';
import '../domain/server_discovery.dart';
import '../domain/settings_repository.dart';
import 'account_settings_json.dart';
import 'accounts_lock.dart';
import 'gmail/gmail_tokens.dart';
import 'imap/password_credentials.dart';
import 'mail_store.dart';
import 'postino_database.dart';
import 'sync_engine.dart';

@LazySingleton(as: AccountsRepository)
class AccountsService(
  final MailStore _store,
  final GoogleConsent _consent,
  final SecureStore _keychain,
  final SyncEngine _sync,
  final PostinoDatabase _db,
  final Clock _clock,
  final SettingsRepository _settings,
  final AccountsLock _lock,
  final ServerDiscovery _discovery,
  final ConnectionTester _tester,
) implements AccountsRepository {
  @override
  Stream<List<Account>> watchAccounts() => _store.watchAccounts();

  @override
  Future<Result<Account>> connectGmail({String? loginHint}) async {
    final GoogleGrant grant;
    switch (await _consent.run(loginHint: loginHint)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        grant = value;
    }
    if (loginHint != null && normalizedAddress(loginHint) != normalizedAddress(grant.address)) {
      return Err(WrongAccountFailure(loginHint));
    }
    // Gmail addresses are case-insensitive: normalized once, so id and stored address agree for onboarding and every reconnection.
    final address = normalizedAddress(grant.address);
    final id = accountIdOf(ProviderKind.gmail, address);
    if (await _connectedElsewhere(id, address)) return const Err(AlreadyConnectedFailure());
    // Under the lock: a removal of the same Account in flight never deletes these credentials.
    final account = await _lock.run(() async {
      await GmailTokens.of(grant).write(_keychain, id);
      return _save(id, address, ProviderKind.gmail);
    });
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
    final provider = passwordProviderFor(normalized);
    if (provider == null) return const Err(UseGmailFailure());
    final id = accountIdOf(provider.kind, normalized);
    final known = (await _store.accounts()).where((a) => a.id == id).firstOrNull;
    if (known?.status == AccountStatus.attivo || await _connectedElsewhere(id, normalized)) {
      return const Err(AlreadyConnectedFailure());
    }
    // A reconnection keeps the servers the Account was saved with; one arrived from another device has none here
    // (they are not in the synced voce, ADR 0016), so the preset or the discovery finds them.
    final saved = known == null ? null : (await PasswordCredentials.read(_keychain, id))?.servers;
    final chosen = servers ?? saved ?? provider.preset ?? await _discovery.discover(normalized);
    if (chosen == null) return const Err(ServerNotFoundFailure());
    switch (await _tester.test(chosen, user: normalized, password: password)) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
    }
    // The user closed the form while the servers answered: nothing is written.
    if (cancelled) return const Err(CancelledFailure());
    final account = await _lock.run(() async {
      await PasswordCredentials(password: password, servers: chosen).write(_keychain, id);
      return _save(id, normalized, provider.kind);
    });
    unawaited(_sync.syncAll());
    return Ok(account);
  }

  /// True when another Account than [id] has [address]: the same mailbox (a Google Workspace one, say) through
  /// another Provider would be a second Account.
  Future<bool> _connectedElsewhere(String id, String address) async =>
      (await _store.accounts()).any((a) => a.address == address && a.id != id);

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
      // After the last one: a count would collide once Accounts are removed or arrive from another device.
      position: known?.position ?? (all.isEmpty ? 0 : all.map((a) => a.position).reduce(max) + 1),
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
        // Under the lock, the Account checked again: one removed during the consent gets no credentials.
        return _lock.run(() async {
          if (!await _db.accountsDao.exists(account.id)) return const Err(NotFoundFailure());
          await GmailTokens.of(value).write(_keychain, account.id);
          return const Ok(null);
        });
    }
  }
}
