import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/mail_provider.dart';
import '../domain/result.dart';
import 'mail_store.dart';

/// Minimal sync engine: initial sync of every Account from its Provider into the database.
// ponytail: initial sync only, run at app start; cursor storage, incremental sync and IDLE come with the next steps.
@lazySingleton
class SyncEngine {
  SyncEngine(this._store);
  final MailStore _store;

  Future<void> syncAll() async {
    await Future.wait([
      for (final account in await _store.accounts())
        // A Da ricollegare Account stops syncing until the user consents again.
        if (account.status == AccountStatus.attivo)
          _sync(account.id, GetIt.I<MailProvider>(instanceName: account.id)),
    ]);
  }

  Future<void> _sync(String accountId, MailProvider provider) async {
    switch (await provider.initialSync()) {
      case Ok(:final value):
        await _store.applySync(accountId, value, fullSnapshot: true);
      case Err(failure: AuthFailure()):
        await _store.setStatus(accountId, AccountStatus.daRicollegare);
      case Err():
        break;
    }
  }
}
