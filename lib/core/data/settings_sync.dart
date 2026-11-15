import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../domain/platform_services.dart';
import '../domain/result.dart';
import '../domain/settings_backend.dart';
import '../domain/settings_document.dart';
import '../domain/settings_entry.dart';
import '../domain/settings_merge.dart';
import '../domain/settings_repository.dart';
import '../domain/settings_sync_control.dart';
import '../domain/sync_status.dart';
import '../domain/synced_settings.dart';
import 'postino_database.dart';
import 'sync/settings_backend_factory.dart';
import 'sync/sync_status_board.dart';

/// How often the file is read again, for the changes made on the other devices.
const settingsPollEvery = Duration(seconds: 60);

/// How long the local writes must pause before they are uploaded.
const settingsDebounce = Duration(seconds: 5);

/// Syncs the Impostazioni di Postino with the file on the Account chosen in "Sincronizza su…" (ADR 0016),
/// separate from the mail's SyncEngine. A cycle runs at start, back in foreground, when the choice changes, when
/// the network returns, every [settingsPollEvery] and [settingsDebounce] after the local writes; never two at once.
/// Offline or on an error the voci stay dirty for the next cycle; the Account's status is never touched. The outcome
/// of the last cycle goes on a [SyncStatusBoard] by Account di sincronizzazione, for «Sincronizza su…» (#317).
@lazySingleton
class SettingsSync(
  final PostinoDatabase _db,
  final SettingsRepository _settings,
  final Clock _clock,
  final Connectivity _connectivity, {
  @ignoreParam final SettingsBackend Function(String accountId) _backendFor = settingsBackendFor,
  @ignoreParam final Duration _stopWait = const Duration(seconds: 5),
}) implements SettingsSyncControl {
  late final _status = SyncStatusBoard(_clock);
  final _subs = <StreamSubscription<Object?>>[];
  StreamSubscription<void>? _debounce;
  Future<void>? _running;
  var _again = false;

  /// Starts listening to the choice of the Account, the poll, the network and the local writes.
  void start() {
    _subs
      // Its first value is the cycle at start.
      ..add(_settings.watchSettingsSyncAccount().distinct().listen((_) => unawaited(syncNow())))
      ..add(_clock.every(settingsPollEvery).listen((_) => unawaited(syncNow())))
      ..add(
        _connectivity.onChanged.listen((online) {
          if (online) unawaited(syncNow());
        }),
      )
      ..add(
        _db.postinoSettingsDao.watchDirty().listen((dirty) {
          if (dirty > 0) _debounceSync();
        }),
      );
  }

  /// Stops every trigger and waits for the cycle in flight, so the database can be closed after it; at most
  /// [_stopWait], so quitting never hangs on a stalled cycle (its voci stay dirty for the next start).
  Future<void> stop() async {
    final subs = [..._subs, ?_debounce];
    _subs.clear();
    _debounce = null;
    await Future.wait([for (final s in subs) s.cancel()]);
    await _running?.timeout(_stopWait, onTimeout: () => debugPrint('[settings] stop: cycle still in flight'));
  }

  @override
  Stream<Map<String, SyncStatus>> watchStatus() => _status.watch();

  /// Runs a cycle now; while one runs, one more follows it and this completes after it.
  @override
  Future<void> syncNow() {
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _run();
  }

  Future<void> _run() async {
    try {
      do {
        _again = false;
        try {
          await _cycle();
        } on Object catch (e) {
          debugPrint('[settings] sync failed: $e');
        }
      } while (_again);
    } finally {
      _running = null;
    }
  }

  void _debounceSync() {
    unawaited(_debounce?.cancel());
    _debounce = _clock.every(settingsDebounce).listen((_) {
      unawaited(_debounce?.cancel());
      _debounce = null;
      unawaited(syncNow());
    });
  }

  /// A cycle on the Account di sincronizzazione, if there is one and the network is there; its outcome goes on
  /// the board.
  Future<void> _cycle() async {
    // A one-off read: `.first` on a Drift watch never completes inside the widget tests' fake async.
    final accountId = await _settings.settingsSyncAccount();
    if (accountId == null || !_connectivity.isOnline) return;
    _status.started(accountId);
    Failure? failure;
    try {
      failure = await _exchange(accountId);
    } on Object catch (e) {
      failure = UnexpectedFailure(e);
    }
    if (failure != null) debugPrint('[settings] $accountId: sync failed, $failure');
    _status.finished(accountId, failure: failure);
  }

  /// Reads the file, merges, applies here the remote copies that won, writes the file if it changed and its
  /// version allows it, then marks clean what was uploaded; the [Failure] that stopped it, if one did.
  Future<Failure?> _exchange(String accountId) async {
    final backend = _backendFor(accountId);
    final local = {
      for (final e in await _db.postinoSettingsDao.entries())
        if (isSyncedSetting(e.key)) e.key: e,
    };

    final SettingsDocument remote;
    switch (await backend.read()) {
      case Err(:final failure):
        return failure;
      case Ok(value: null):
        remote = SettingsDocument(schemaVersion: settingsSchemaVersion, entries: const {});
      case Ok(:final value?):
        switch (decodeSettings(value)) {
          case Err(:final failure):
            // Never overwrite what cannot be read.
            return failure;
          case Ok(value: final doc):
            remote = doc;
        }
    }

    final merged = mergeSettings(local, remote.entries);
    // Voci outside the closed list (a newer Postino's) stay in the file but never come here.
    await _db.postinoSettingsDao.applyRemote([
      for (final e in merged.values)
        if (isSyncedSetting(e.key) && local[e.key] != e) e,
    ]);
    // A newer Postino's file is never overwritten: the voci here stay dirty until this one is updated, and the cycle
    // is not a success while they wait (#317).
    if (!remote.writable) {
      return _same(merged, remote.entries) ? null : const UnexpectedFailure('file from a newer Postino: update it');
    }
    if (!_same(merged, remote.entries)) {
      if (await backend.write(encodeSettings(merged.values)) case Err(:final failure)) {
        return failure;
      }
    }
    await _db.postinoSettingsDao.markClean([
      for (final e in local.values)
        if (merged[e.key] == e) e,
    ]);
    return null;
  }

  static bool _same(Map<String, SettingsEntry> a, Map<String, SettingsEntry> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

@module
abstract class SettingsSyncModule() {
  /// The UI sees the sync of the Impostazioni only through [SettingsSyncControl].
  @lazySingleton
  SettingsSyncControl settingsSyncControl(SettingsSync sync) => sync;
}
