import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'gmail/gmail_tokens.dart';
import 'gmail/google_revoke.dart';
import 'imap/password_credentials.dart';
import 'mail_store.dart';
import 'sync_engine.dart';

@LazySingleton(as: AccountsRepository)
class AccountsService(
  final MailStore _store,
  final GoogleConsent _consent,
  final SecureStore _keychain,
  final SyncEngine _sync,
  final ServerDiscovery _discovery,
  final ConnectionTester _tester,
  final GoogleRevoke _revoke,
  final SettingsRepository _settings,
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
    if (loginHint != null && loginHint.trim().toLowerCase() != grant.address.trim().toLowerCase()) {
      return Err(WrongAccountFailure(loginHint));
    }
    // ponytail: id = provider:address, so the same mailbox is the same Account; a separate uuid if addresses ever change.
    // Gmail addresses are case-insensitive: normalized once, so id and stored address agree for onboarding and every reconnection.
    final address = grant.address.trim().toLowerCase();
    final id = 'gmail:$address';
    if (await _connectedElsewhere(id, address)) return const Err(AlreadyConnectedFailure());
    await GmailTokens.of(grant).write(_keychain, id);
    return Ok(await _save(id, address, ProviderKind.gmail));
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
    final normalized = address.trim().toLowerCase();
    final provider = passwordProviderFor(normalized);
    if (provider == null) return const Err(UseGmailFailure());
    final id = '${provider.kind.name}:$normalized';
    final known = (await _store.accounts()).where((a) => a.id == id).firstOrNull;
    if (known?.status == AccountStatus.attivo || await _connectedElsewhere(id, normalized)) {
      return const Err(AlreadyConnectedFailure());
    }
    // A reconnection keeps the servers the Account was saved with.
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
    await PasswordCredentials(password: password, servers: chosen).write(_keychain, id);
    return Ok(await _save(id, normalized, provider.kind));
  }

  /// True when another Account than [id] has [address]: the same mailbox (a Google Workspace one, say) through
  /// another Provider would be a second Account.
  Future<bool> _connectedElsewhere(String id, String address) async =>
      (await _store.accounts()).any((a) => a.address == address && a.id != id);

  /// Writes the Account [id] as attivo, keeping the color and position it had, then syncs.
  Future<Account> _save(String id, String address, ProviderKind provider) async {
    final all = await _store.accounts();
    final known = all.where((a) => a.id == id).firstOrNull;
    final account = Account(
      id: id,
      address: address,
      provider: provider,
      color: known?.color ?? all.length % accountColorCount,
      // After the last one: a removal leaves a gap, never a duplicate.
      position: known?.position ?? all.fold<int>(-1, (m, a) => a.position > m ? a.position : m) + 1,
    );
    await _store.addAccount(account);
    unawaited(_sync.syncAll());
    return account;
  }

  @override
  Future<Result<void>> grantDriveAccess(String accountId) async {
    final account = (await _store.accounts()).where((a) => a.id == accountId).firstOrNull;
    if (account == null) return const Err(NotFoundFailure());
    switch (await _consent.run(loginHint: account.address, drive: true)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.address.trim().toLowerCase() != account.address) return Err(WrongAccountFailure(account.address));
        await GmailTokens.of(value).write(_keychain, account.id);
        return const Ok(null);
    }
  }

  @override
  Future<void> remove(String accountId) async {
    if (!(await _store.accounts()).any((a) => a.id == accountId)) return;
    // Read before the keychain is cleared; a keychain that does not answer never blocks the removal.
    final tokens = await GmailTokens.read(_keychain, accountId).catchError((Object _) => null);
    await _sync.removeAccount(accountId, () => _store.removeAccount(accountId));
    // The Impostazioni di Postino no longer have a Drive to sync on.
    if (await _settings.settingsSyncAccount() == accountId) await _settings.setSettingsSyncAccount(null);
    if (tokens != null) await _revoke.revoke(tokens.refresh);
    // Last, so a token refresh still running meanwhile cannot write them back; each one on its own, so a keychain
    // that refuses one never leaves the other.
    for (final delete in [GmailTokens.delete, PasswordCredentials.delete]) {
      try {
        await delete(_keychain, accountId);
      } on Object catch (e) {
        debugPrint('[accounts] $accountId: keychain delete failed, ${e.runtimeType}');
      }
    }
  }
}
