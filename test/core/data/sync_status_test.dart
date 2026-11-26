// The sync status the engine keeps per Account (#251): running, last update, failure, in memory only.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/sync/outbox_sender.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/sync_status.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _message = OutgoingMessage(
  messageId: '<m@example.com>',
  from: 'a@example.com',
  to: ['b@example.com'],
  subject: 's',
  body: 'x',
);

void main() {
  late Harness h;
  late FakeMailProvider a;
  late SyncEngine engine;
  late List<Map<String, SyncStatus>> seen;

  setUp(() async {
    h = await Harness.create();
    a = await h.addAccount('a');
    engine = GetIt.I<SyncEngine>();
    seen = [];
    final sub = engine.watchSyncStatus().listen(seen.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
  });

  SyncStatus? last() => seen.last['a'];

  test('nothing before the first sync; then running, then synced at the clock time', () async {
    expect(seen.single, isEmpty);
    a.hold = Completer<void>();
    final sync = engine.syncAll();
    await pumpEventQueue();
    expect(last()?.running, isTrue);
    expect(last()?.syncedAt, isNull);

    a.hold!.complete();
    await sync;
    expect(last(), SyncStatus(syncedAt: h.clock.now()));
  });

  test('a failed sync keeps the last update and counts the failures in a row; one that works clears them', () async {
    await engine.syncAll();
    final synced = h.clock.now();
    h.clock.advance(const Duration(minutes: 5));
    a.goOffline();
    for (var i = 0; i < 3; i++) {
      await engine.syncAll();
    }
    expect(last()?.failure, isA<OfflineFailure>());
    expect(last()?.failures, 3);
    expect(last()?.failed, isTrue);
    expect(last()?.syncedAt, synced, reason: 'only an update that went through moves it');

    a.goOnline();
    await engine.syncAll();
    expect(last(), SyncStatus(syncedAt: h.clock.now()));
  });

  test('an error shown stays until a sync works: an OfflineFailure after it does not hide it', () async {
    await engine.syncAll();
    a.rateLimit();
    await engine.syncAll();
    // Paused, the slot has no replay to wait for: the status comes a turn later (#394).
    await pumpEventQueue();
    expect(last()?.failed, isTrue);
    a
      ..rateLimit(on: false)
      ..goOffline();
    // Past the pause the rate limit set (#394).
    h.clock.advance(const Duration(minutes: 1));
    await engine.syncAll();
    expect(last()?.failed, isTrue);
    a.goOnline();
    await engine.syncAll();
    expect(last()?.failed, isFalse);
  });

  test('refresh is no success while the Provider\'s pause keeps an Account from syncing', () async {
    await engine.syncAll();
    a.rateLimit(retryAfter: h.clock.now().add(const Duration(minutes: 5)));
    await engine.syncAll();
    a.rateLimit(on: false);
    final before = a.syncCalls;
    expect(await engine.refresh(), isFalse);
    expect(a.syncCalls, before, reason: 'paused: not even tried');
  });

  test('«Riprova» while a failed sync still sends the outbox syncs again, behind the send', () async {
    // The initial sync: its answer comes after [hold], offline by then.
    a.hold = Completer<void>();
    final running = engine.syncAll();
    await pumpEventQueue();
    await engine.send('a', _message);
    h.clock.advance(sendWindow);
    a
      ..holdSend = Completer<void>()
      ..goOffline();
    a.hold!.complete();
    await pumpEventQueue();
    expect(last()?.failure, isA<OfflineFailure>());
    expect(a.sendCalls, 1, reason: 'the slot is sending the outbox');

    a.goOnline();
    final calls = a.syncCalls;
    final retry = engine.refresh();
    a.holdSend!.complete();
    expect(await retry, isTrue);
    expect(a.syncCalls, calls + 1);
    await running;
  });

  test('a refused access fails at once', () async {
    a.breakAuth();
    await engine.syncAll();
    expect(last()?.failure, isA<AuthFailure>());
    expect(last()?.failed, isTrue);
  });

  test('refresh says whether every Account went through', () async {
    final sync = GetIt.I<MailSync>();
    // Each after the slot of the one before: a refresh during its uploads joins its finished sync phase.
    expect(await sync.refresh(), isTrue);
    await pumpEventQueue();
    a.goOffline();
    expect(await sync.refresh(), isFalse);
    await pumpEventQueue();
    a.goOnline();
    expect(await sync.refresh(), isTrue);
  });

  test('a refresh while a sync runs joins it: one sync, and its outcome', () async {
    a.hold = Completer<void>();
    final running = engine.syncAll();
    await pumpEventQueue();
    final refresh = engine.refresh();
    await pumpEventQueue();
    a.goOffline();
    a.hold!.complete();
    await running;
    expect(await refresh, isFalse);
    expect(a.syncCalls, 1);
  });

  test('a removed Account leaves the status', () async {
    await engine.syncAll();
    await engine.removeAccount('a', () async {});
    await pumpEventQueue();
    expect(seen.last, isEmpty);
  });

  test('a new listener gets the status now first', () async {
    await engine.syncAll();
    expect((await engine.watchSyncStatus().first)['a']?.syncedAt, h.clock.now());
  });
}
