import 'dart:async';

import '../../domain/platform_services.dart';
import '../../domain/result.dart';
import '../../domain/sync_status.dart';

/// The [SyncStatus] of every Account (#251), as its syncs start and end; in memory only.
class SyncStatusBoard(final Clock _clock) {
  final _all = <String, SyncStatus>{};
  final _changes = StreamController<Map<String, SyncStatus>>.broadcast();

  /// The Account's status now; null before its first sync of this run.
  SyncStatus? of(String accountId) => _all[accountId];

  /// Every Account's status now, then at every change.
  Stream<Map<String, SyncStatus>> watch() => Stream.multi((listener) {
    listener.add(Map.unmodifiable(_all));
    final changes = _changes.stream.listen(listener.add);
    listener.onCancel = changes.cancel;
  });

  /// A sync of the Account starts.
  void started(String accountId) {
    final s = _all[accountId] ?? const SyncStatus();
    _set(accountId, SyncStatus(running: true, syncedAt: s.syncedAt, failure: s.failure, failures: s.failures));
  }

  /// The sync ends: through ([failure] null), failed, or not even tried ([synced] false: the Provider's pause holds).
  void finished(String accountId, {Failure? failure, bool synced = true}) {
    final s = _all[accountId] ?? const SyncStatus();
    _set(accountId, switch ((failure, synced)) {
      (null, true) => SyncStatus(syncedAt: _clock.now()),
      (final f?, _) => SyncStatus(syncedAt: s.syncedAt, failure: f, failures: s.failures + 1),
      (null, false) => SyncStatus(syncedAt: s.syncedAt, failure: s.failure, failures: s.failures),
    });
  }

  /// The Account is gone (#174).
  void forget(String accountId) {
    if (_all.remove(accountId) != null) _changes.add(Map.unmodifiable(_all));
  }

  void _set(String accountId, SyncStatus status) {
    _all[accountId] = status;
    _changes.add(Map.unmodifiable(_all));
  }
}
