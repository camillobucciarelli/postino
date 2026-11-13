import 'package:equatable/equatable.dart';

import 'result.dart';

/// Where the sync of an Account stands (#251), kept in memory only: it starts over at every launch.
class const SyncStatus({
  /// A sync of the Account runs now.
  final bool running = false,

  /// When its last sync went through; null before the first one of this run.
  final DateTime? syncedAt,

  /// Why its last sync failed; null when it went through.
  final Failure? failure,

  /// Its syncs failed in a row, the last one included.
  final int failures = 0,
}) extends Equatable {
  /// Crea lo stato; senza argomenti nessuna sincronizzazione è ancora avvenuta.
  this;

  /// Several Accounts (the Posta unificata) as one: running while any runs, failed while any failed, synced at the
  /// oldest of their syncs, the time by which all of them were current.
  factory SyncStatus.merge(Iterable<SyncStatus> all) {
    final list = all.toList();
    final failed = list.where((s) => s.failed).firstOrNull;
    final times = [for (final s in list) ?s.syncedAt]..sort();
    return SyncStatus(
      running: list.any((s) => s.running),
      syncedAt: times.firstOrNull,
      failure: failed?.failure,
      failures: failed?.failures ?? 0,
    );
  }

  /// An [OfflineFailure] while the device says it is online is a blip until it repeats this many times: more is a
  /// sync that never gets through (#252), which the user is told about as a failure, not as being offline.
  static const offlineFailuresToShow = 3;

  /// Whether the user is told the sync failed (the device online: offline is told apart before this).
  bool get failed => failure != null && (failure is! OfflineFailure || failures >= offlineFailuresToShow);

  @override
  List<Object?> get props => [running, syncedAt, failure, failures];
}
