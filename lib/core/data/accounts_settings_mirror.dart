import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../domain/platform_services.dart';
import 'account_settings_json.dart';
import 'gmail/gmail_tokens.dart';
import 'postino_database.dart';
import 'row_mappers.dart';

const _prefix = 'accounts/';

/// Keeps the `accounts` table a mirror of the voci `accounts/<accountId>` of the Impostazioni di Postino
/// (ADR 0016), the source of truth for address, Provider, color and position; the status stays local.
/// - a live voce for an Account missing here adds it da ricollegare: no credentials, the SyncEngine skips it;
/// - a live voce for an Account here updates address, color and position, keeping its status;
/// - a tombstone removes the Account here, its local mail and its credentials;
/// - an Account here without a voce is left alone.
@lazySingleton
class AccountsSettingsMirror(final PostinoDatabase _db, final SecureStore _keychain) {
  StreamSubscription<void>? _sub;

  /// Aligns the Accounts now, then at each change of their voci.
  void start() {
    _sub ??= _db.postinoSettingsDao
        .watchPrefix(_prefix)
        .asyncMap((_) => reconcile().catchError((Object e) => debugPrint('[accounts] mirror: $e')))
        .listen(null);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// One pass, in a transaction that reads the voci again: a connection writing the Account and its voce together
  /// is seen whole or not at all, so its Account is never taken for a removed one.
  @visibleForTesting
  Future<void> reconcile() => _db.transaction(() async {
    final here = {for (final r in await _db.accountsDao.byPosition()) r.id: accountOf(r)};
    for (final row in await _db.postinoSettingsDao.readPrefix(_prefix)) {
      final id = row.key.substring(_prefix.length);
      final local = here[id];
      if (row.deleted) {
        if (local == null) continue;
        // Credentials first: a crash in between leaves an Account da ricollegare, never a token without its Account.
        await GmailTokens.delete(_keychain, id);
        await _db.accountsDao.remove(id);
        continue;
      }
      final synced = decodeAccountSettings(id, row.value);
      if (synced == null) continue;
      if (local == null) {
        await _db.accountsDao.upsert(synced);
      } else if (!sameAccountSettings(local, synced)) {
        await _db.accountsDao.updateSettings(synced);
      }
    }
  });
}
