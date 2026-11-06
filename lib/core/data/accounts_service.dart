import 'dart:async';

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
import 'gmail/gmail_tokens.dart';
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
    await GmailTokens.of(grant).write(_keychain, id);
    return Ok(await _save(id, address, ProviderKind.gmail));
  }

  @override
  Future<Result<Account>> connectWithPassword(String address, String password, {ServerSettings? servers}) async {
    final normalized = address.trim().toLowerCase();
    final provider = passwordProviderFor(normalized);
    if (provider == null) return const Err(UseGmailFailure());
    final id = '${provider.kind.name}:$normalized';
    final known = (await _store.accounts()).where((a) => a.id == id).firstOrNull;
    if (known?.status == AccountStatus.attivo) return const Err(AlreadyConnectedFailure());
    // A reconnection keeps the servers the Account was saved with.
    final saved = known == null ? null : (await PasswordCredentials.read(_keychain, id))?.servers;
    final chosen = servers ?? saved ?? provider.preset ?? await _discovery.discover(normalized);
    if (chosen == null) return const Err(ServerNotFoundFailure());
    switch (await _tester.test(chosen, user: normalized, password: password)) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
    }
    await PasswordCredentials(password: password, servers: chosen).write(_keychain, id);
    return Ok(await _save(id, normalized, provider.kind));
  }

  /// Writes the Account [id] as attivo, keeping the color and position it had, then syncs.
  Future<Account> _save(String id, String address, ProviderKind provider) async {
    final all = await _store.accounts();
    final known = all.where((a) => a.id == id).firstOrNull;
    final account = Account(
      id: id,
      address: address,
      provider: provider,
      color: known?.color ?? all.length % accountColorCount,
      // ponytail: no Account removal yet, so the count is the next free position.
      position: known?.position ?? all.length,
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
}
