import 'dart:async';

import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/accounts_repository.dart';
import '../domain/google_consent.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';
import 'gmail/gmail_tokens.dart';
import 'mail_store.dart';
import 'sync_engine.dart';

@LazySingleton(as: AccountsRepository)
class AccountsService(this._store, this._consent, this._keychain, this._sync) implements AccountsRepository {
  final MailStore _store;
  final GoogleConsent _consent;
  final SecureStore _keychain;
  final SyncEngine _sync;

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
    final all = await _store.accounts();
    final known = all.where((a) => a.id == id).firstOrNull;
    final account = Account(
      id: id,
      address: address,
      provider: ProviderKind.gmail,
      color: known?.color ?? all.length % accountColorCount,
      // ponytail: no Account removal yet, so the count is the next free position.
      position: known?.position ?? all.length,
    );
    await _store.addAccount(account);
    unawaited(_sync.syncAll());
    return Ok(account);
  }
}
