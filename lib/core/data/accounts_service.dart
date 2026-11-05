import 'dart:async';
import 'dart:math';

import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/accounts_repository.dart';
import '../domain/google_consent.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';
import '../domain/settings_repository.dart';
import 'account_settings_json.dart';
import 'gmail/gmail_tokens.dart';
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
    final account = await _save(id, address);
    unawaited(_sync.syncAll());
    return Ok(account);
  }

  /// The Account here and its synced voce (ADR 0016), in one transaction: the AccountsSettingsMirror sees both or
  /// neither. A known Account (da ricollegare, maybe from another device) keeps color and position, and its voce is
  /// written only if it says something else, so a reconnection does not move the voce's updatedAt.
  /// With the sync off (the onboarding comes before «Sincronizza su…») a new voce is one written before the sync:
  /// the copy of another device wins over its default color and position. With the sync on it is stamped now, so
  /// an older tombstone does not remove an Account just connected on purpose.
  Future<Account> _save(String id, String address) => _db.transaction(() async {
    final all = await _store.accounts();
    final known = all.where((a) => a.id == id).firstOrNull;
    final account = Account(
      id: id,
      address: address,
      provider: ProviderKind.gmail,
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
        if (value.address.trim().toLowerCase() != account.address) return Err(WrongAccountFailure(account.address));
        await GmailTokens.of(value).write(_keychain, account.id);
        return const Ok(null);
    }
  }
}
