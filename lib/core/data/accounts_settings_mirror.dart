import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../domain/account.dart';
import '../domain/platform_services.dart';
import '../domain/settings_repository.dart';
import '../domain/synced_settings.dart';
import 'account_settings_json.dart';
import 'accounts_lock.dart';
import 'gmail/gmail_tokens.dart';
import 'postino_database.dart';
import 'row_mappers.dart';

/// Keeps the `accounts` table a mirror of the voci `accounts/<accountId>` of the Impostazioni di Postino
/// (ADR 0016), the source of truth for address, Provider, color and position; the status stays local.
/// - a live voce for an Account missing here adds it da ricollegare: no credentials, the SyncEngine skips it;
/// - a live voce for an Account here updates address, color and position, keeping its status;
/// - a tombstone removes the Account here, its local mail and its credentials; for the Account the sync runs on,
///   only once the tombstone is uploaded (clean), as uploading needs its credentials, then the sync goes off;
/// - an Account here without a voce is left alone.
/// A pass that fails (a locked keychain) is tried again after [_retryAfter], doubling up to 32 times it.
@lazySingleton
class AccountsSettingsMirror(
  final PostinoDatabase _db,
  final SecureStore _keychain,
  final SettingsRepository _settings,
  final AccountsLock _lock, {
  @ignoreParam final Duration _retryAfter = const Duration(seconds: 30),
}) {
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _retry;
  var _failures = 0;
  Future<void>? _running;
  var _again = false;

  /// Aligns the Accounts now, then at each change of their voci, of the Account the sync runs on or of a status.
  void start() {
    if (_subs.isNotEmpty) return;
    _subs
      ..add(_db.postinoSettingsDao.watchPrefixWithTombstones(accountsSettingPrefix).listen((_) => _kick()))
      // A removal held for the sync Account goes on once another one, or none, is chosen. Its first value is the
      // choice at start, which the first pass of the voci already reads.
      ..add(_settings.watchSettingsSyncAccount().distinct().skip(1).listen((_) => _kick()))
      // A held removal goes on too once the sync Account turns da ricollegare (it can no longer upload).
      ..add(
        _db.accountsDao
            .watchByPosition()
            .map((rows) => [for (final r in rows) '${r.id} ${r.status.name}'].join('\n'))
            .distinct()
            .skip(1)
            .listen((_) => _kick()),
      );
  }

  /// Stops the triggers and the retry, and waits for the pass in flight.
  Future<void> stop() async {
    _retry?.cancel();
    _retry = null;
    final subs = [..._subs];
    _subs.clear();
    await Future.wait([for (final s in subs) s.cancel()]);
    await _running;
  }

  /// A pass now; while one runs, one more after it. Never two at once.
  void _kick() {
    if (_running != null) {
      _again = true;
      return;
    }
    _running = _run();
  }

  Future<void> _run() async {
    try {
      do {
        _again = false;
        _retry?.cancel();
        try {
          await reconcile();
          _failures = 0;
        } on Object catch (e) {
          debugPrint('[accounts] mirror: $e');
          // ponytail: retried while the app runs, at most every 32 × _retryAfter; nothing persists across a restart,
          // where the first pass tries again anyway.
          if (_subs.isNotEmpty) _retry = Timer(_retryAfter * (1 << min(_failures++, 5)), _kick);
        }
      } while (_again);
    } finally {
      _running = null;
    }
  }

  /// One pass, in a transaction that reads the voci again: a connection writing the Account and its voce together
  /// is seen whole or not at all, so its Account is never taken for a removed one.
  @visibleForTesting
  /// Under the AccountsLock, taken before the transaction as connectGmail does: a reconnection in flight is never
  /// left without the credentials it just wrote.
  Future<void> reconcile() => _lock.run(
    () => _db.transaction(() async {
      final syncAccount = await _settings.settingsSyncAccount();
      final here = {for (final r in await _db.accountsDao.byPosition()) r.id: accountOf(r)};
      for (final row in await _db.postinoSettingsDao.readPrefixWithTombstones(accountsSettingPrefix)) {
        final id = row.key.substring(accountsSettingPrefix.length);
        final local = here[id];
        if (row.deleted) {
          if (local == null) {
            // Removed here already (or never here): the sync cannot run on it.
            if (id == syncAccount) await _settings.setSettingsSyncAccount(null);
            continue;
          }
          // Uploading the tombstone of the sync Account needs its credentials: removed here once in the file, else the
          // other devices never see the removal. The markClean of the upload changes the row, and the pass comes again.
          // ponytail: a file this Postino cannot write (a newer one) holds the removal until Postino is updated.
          // An Account da ricollegare cannot upload: removed at once, its tombstone stays dirty and reaches the other
          // devices once another Account is chosen for the sync.
          if (row.dirty && id == syncAccount && local.status != AccountStatus.daRicollegare) continue;
          // Credentials first: a crash in between leaves an Account da ricollegare, never a token without its Account.
          // ponytail: a token refresh in flight may write the credentials again after this; the window is narrow and
          // the token never leaves the device. A per-Account lock with the refresh if it ever matters.
          await GmailTokens.delete(_keychain, id);
          await _db.accountsDao.remove(id);
          // The sync ran on it: off, instead of failing in silence on an Account without credentials.
          if (id == syncAccount) await _settings.setSettingsSyncAccount(null);
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
    }),
  );
}
