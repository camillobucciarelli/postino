import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../domain/mail_provider.dart';
import '../domain/result.dart';
import 'mail_store.dart';

/// Minimal sync engine: initial sync of every Account from its Provider into the database.
// ponytail: initial sync only, run at app start; cursor storage, incremental sync, IDLE and AuthFailure -> Da ricollegare come with the next steps.
@lazySingleton
class SyncEngine {
  SyncEngine(this._store);
  final MailStore _store;

  Future<void> syncAll() => Future.wait([
    for (final account in _store.accounts())
      _sync(account.id, GetIt.I<MailProvider>(instanceName: account.id)),
  ]);

  Future<void> _sync(String accountId, MailProvider provider) async {
    if (await provider.initialSync() case Ok(:final value)) {
      _store.applySync(accountId, value);
    }
  }
}
