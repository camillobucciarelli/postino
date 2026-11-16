import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../domain/platform_services.dart';
import '../domain/result.dart';
import '../domain/settings_backend.dart';
import '../domain/settings_repository.dart';
import '../domain/settings_sync_control.dart';
import '../domain/sync_status.dart';
import 'postino_database.dart';
import 'sync/settings_backend_factory.dart';
import 'sync/settings_exchange.dart';
import 'sync/sync_key.dart';
import 'sync/sync_key_store.dart';
import 'sync/sync_status_board.dart';

/// How often the file is read again, for the changes made on the other devices.
const settingsPollEvery = Duration(seconds: 60);

/// How long the local writes must pause before they are uploaded.
const settingsDebounce = Duration(seconds: 5);

/// Syncs the Impostazioni di Postino with the file on the Account chosen in "Sincronizza su…" (ADR 0016),
/// separate from the mail's SyncEngine. A cycle runs at start, back in foreground, when the choice changes, when
/// the network returns, every [settingsPollEvery] and [settingsDebounce] after the local writes; never two at once,
/// nor at once with a pairing or «Rigenera la chiave». Offline or on an error the voci stay dirty for the next cycle;
/// the Account's status is never touched. The outcome of the last cycle goes on a [SyncStatusBoard] by Account di
/// sincronizzazione, for «Sincronizza su…» (#317). The file is sealed with the Chiave di sincronizzazione (ADR 0019).
@lazySingleton
class SettingsSync(
  final PostinoDatabase _db,
  final SettingsRepository _settings,
  final Clock _clock,
  final Connectivity _connectivity,
  final SyncKeyStore _keys, {
  @ignoreParam final SettingsBackend Function(String accountId) _backendFor = settingsBackendFor,
  @ignoreParam final Duration _stopWait = const Duration(seconds: 5),
}) implements SettingsSyncControl {
  late final _status = SyncStatusBoard(_clock);
  late final _exchange = SettingsExchange(_db, _keys);
  final _subs = <StreamSubscription<Object?>>[];
  StreamSubscription<void>? _debounce;

  /// The last job queued: cycles, pairings and regenerations run one after the other.
  Future<void> _tail = Future.value();

  /// A cycle queued and not started yet: a [syncNow] meanwhile joins it.
  Future<void>? _queued;

  /// Jobs queued or running.
  var _jobs = 0;

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

  /// Stops every trigger and waits for the job in flight, so the database can be closed after it; at most
  /// [_stopWait], so quitting never hangs on a stalled cycle (its voci stay dirty for the next start).
  Future<void> stop() async {
    final subs = [..._subs, ?_debounce];
    _subs.clear();
    _debounce = null;
    await Future.wait([for (final s in subs) s.cancel()]);
    await _tail.timeout(_stopWait, onTimeout: () => debugPrint('[settings] stop: cycle still in flight'));
  }

  @override
  Stream<Map<String, SyncStatus>> watchStatus() => _status.watch();

  /// Runs a cycle now; while one runs, one more follows it and this completes after it.
  @override
  Future<void> syncNow() {
    if (_queued case final queued?) return queued;
    if (_jobs == 0) return _alone(_quietCycle);
    return _queued = _alone(() {
      _queued = null;
      return _quietCycle();
    });
  }

  /// A cycle that never throws (callers leave it unawaited), as a `Future<void>` of its own: callers give it a void
  /// `onTimeout`.
  Future<void> _quietCycle() async {
    try {
      await _cycle();
    } on Object catch (e) {
      debugPrint('[settings] sync failed: $e');
    }
  }

  @override
  Future<String?> pairingCode() async => (await _keys.read())?.code;

  @override
  Future<Result<void>> pair(String code) async {
    final key = SyncKey.fromCode(code);
    if (key == null) return const Err(PairingCodeFailure());
    final paired = await _alone(() => _onAccount((backend) => _exchange.pair(backend, key)));
    if (paired is Ok) unawaited(syncNow());
    return paired;
  }

  @override
  Future<Result<void>> regenerateKey() => _alone(() async {
    try {
      return await _cycle(regenerate: true);
    } on Object catch (e) {
      return Err(UnexpectedFailure(e));
    }
  });

  /// [job] after every job queued before it; at once when none is.
  Future<T> _alone<T>(Future<T> Function() job) {
    final result = _jobs++ == 0 ? Future.sync(job) : _tail.then((_) => job());
    _tail = result
        .then<void>((_) {}, onError: (Object e) => debugPrint('[settings] sync failed: $e'))
        .whenComplete(() => _jobs--);
    return result;
  }

  void _debounceSync() {
    unawaited(_debounce?.cancel());
    _debounce = _clock.every(settingsDebounce).listen((_) {
      unawaited(_debounce?.cancel());
      _debounce = null;
      unawaited(syncNow());
    });
  }

  /// A cycle on the Account di sincronizzazione, if there is one and the network is there; its outcome goes on the
  /// board, and is the answer.
  Future<Result<void>> _cycle({bool regenerate = false}) async {
    // A one-off read: `.first` on a Drift watch never completes inside the widget tests' fake async.
    final accountId = await _settings.settingsSyncAccount();
    if (accountId == null) return const Err(UnexpectedFailure('no Account di sincronizzazione'));
    if (!_connectivity.isOnline) return const Err(OfflineFailure());
    _status.started(accountId);
    Failure? failure;
    try {
      failure = await _exchange.cycle(_backendFor(accountId), regenerate: regenerate);
    } on Object catch (e) {
      failure = UnexpectedFailure(e);
    }
    if (failure != null) debugPrint('[settings] $accountId: sync failed, $failure');
    _status.finished(accountId, failure: failure);
    return failure == null ? const Ok(null) : Err(failure);
  }

  /// [job] on the backend of the Account di sincronizzazione, online.
  Future<Result<void>> _onAccount(Future<Failure?> Function(SettingsBackend) job) async {
    try {
      final accountId = await _settings.settingsSyncAccount();
      if (accountId == null) return const Err(UnexpectedFailure('no Account di sincronizzazione'));
      if (!_connectivity.isOnline) return const Err(OfflineFailure());
      return switch (await job(_backendFor(accountId))) {
        final f? => Err(f),
        null => const Ok(null),
      };
    } on Object catch (e) {
      return Err(UnexpectedFailure(e));
    }
  }
}

@module
abstract class SettingsSyncModule() {
  /// The UI sees the sync of the Impostazioni only through [SettingsSyncControl].
  @lazySingleton
  SettingsSyncControl settingsSyncControl(SettingsSync sync) => sync;
}
