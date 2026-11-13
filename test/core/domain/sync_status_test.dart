import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/sync_status.dart';

void main() {
  final t1 = DateTime.utc(2026, 11, 13, 9);
  final t2 = DateTime.utc(2026, 11, 13, 10);

  group('failed', () {
    test('any failure but an OfflineFailure at once', () {
      expect(const SyncStatus(failure: AuthFailure(), failures: 1).failed, isTrue);
      expect(const SyncStatus(failure: UnexpectedFailure('x'), failures: 1).failed, isTrue);
    });

    test('an OfflineFailure only once it repeats: online, it is a sync that never gets through (#252)', () {
      expect(const SyncStatus(failure: OfflineFailure(), failures: 1).failed, isFalse);
      expect(const SyncStatus(failure: OfflineFailure(), failures: 2).failed, isFalse);
      expect(const SyncStatus(failure: OfflineFailure(), failures: SyncStatus.offlineFailuresToShow).failed, isTrue);
    });

    test('a stalled request at once: the network is there (#252)', () {
      expect(const SyncStatus(failure: OfflineFailure(stalled: true), failures: 1).failed, isTrue);
    });

    test('nothing failed', () => expect(SyncStatus(syncedAt: t1).failed, isFalse));
  });

  group('merge, the Posta unificata', () {
    test('running while any runs; synced at the oldest sync', () {
      final s = SyncStatus.merge([SyncStatus(syncedAt: t2), SyncStatus(running: true, syncedAt: t1)]);
      expect(s.running, isTrue);
      expect(s.syncedAt, t1);
    });

    test('no time while one Account has not synced yet', () {
      expect(SyncStatus.merge([SyncStatus(syncedAt: t2), const SyncStatus()]).syncedAt, isNull);
    });

    test('failed while any failed, with its failure', () {
      final s = SyncStatus.merge([
        SyncStatus(syncedAt: t2),
        const SyncStatus(failure: OfflineFailure(), failures: 1),
        SyncStatus(syncedAt: t1, failure: const AuthFailure(), failures: 1),
      ]);
      expect(s.failed, isTrue);
      expect(s.failure, isA<AuthFailure>());
      expect(s.running, isFalse);
    });

    test('a single OfflineFailure is no failure for the whole either', () {
      final s = SyncStatus.merge([
        SyncStatus(syncedAt: t2),
        SyncStatus(syncedAt: t1, failure: const OfflineFailure(), failures: 1),
      ]);
      expect(s.failed, isFalse);
      expect(s.syncedAt, t1);
    });

    test('no Account: nothing', () => expect(SyncStatus.merge(const []), const SyncStatus()));
  });
}
