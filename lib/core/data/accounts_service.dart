import 'dart:async';

import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/accounts_repository.dart';
import '../domain/google_consent.dart';
import '../domain/result.dart';
import 'mail_store.dart';
import 'sync_engine.dart';

/// Account colors (ARGB), assigned in turn.
// ponytail: the design system's light account colors as plain ARGB; store PostinoAccountColor when the swatch must follow the theme.
const accountColors = [
  0xFF00779E, // sky
  0xFF3559C3, // blue
  0xFF6C3FAF, // violet
  0xFF95388B, // magenta
  0xFFB43C6B, // rose
  0xFF6B6F00, // olive
  0xFF445465, // slate
  0xFF403D36, // graphite
];

@LazySingleton(as: AccountsRepository)
class AccountsService implements AccountsRepository {
  AccountsService(this._store, this._consent, this._sync);
  final MailStore _store;
  final GoogleConsent _consent;
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
    // ponytail: id = provider:address, so the same mailbox is the same Account; a separate uuid if addresses ever change.
    final id = 'gmail:${grant.address}';
    final all = await _store.accounts();
    final known = all.where((a) => a.id == id).firstOrNull;
    final account = Account(
      id: id,
      address: grant.address,
      provider: ProviderKind.gmail,
      color: known?.color ?? accountColors[all.length % accountColors.length],
      // ponytail: no Account removal yet, so the count is the next free position.
      position: known?.position ?? all.length,
    );
    await _store.addAccount(account);
    unawaited(_sync.syncAll());
    return Ok(account);
  }
}
