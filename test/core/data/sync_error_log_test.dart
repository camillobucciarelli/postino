import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/sync/outbox_sender.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

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

  setUp(() async {
    h = await Harness.create();
    a = await h.addAccount('a');
  });

  test('a sync that fails ends up in the log, with the Account and the error', () async {
    a.breakAuth();
    await GetIt.I<SyncEngine>().syncAll();
    final log = await h.errorLog.read();
    expect(log, contains('[sync a] AuthFailure'));
    expect(await h.errorLog.takeCrashMark(), isFalse, reason: 'a Failure is not a crash');
  });

  test('a send the Provider refuses ends up in the log', () async {
    final engine = GetIt.I<SyncEngine>()..start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    a.sendFailure = const RejectedFailure('Invalid To header');
    await engine.send('a', _message);
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(await h.errorLog.read(), contains('[send a] RejectedFailure(Invalid To header)'));
  });

  test('a replay of the queue that fails ends up in the log', () async {
    a.deliver(msg('1'));
    final engine = GetIt.I<SyncEngine>();
    await engine.syncAll();
    a.setLabelFailure = const RejectedFailure('Etichetta sparita');
    await engine.setLabel('a', '1', 'Label_12', add: true);
    await engine.syncAll();
    expect(await h.errorLog.read(), contains('[action replay a] RejectedFailure(Etichetta sparita)'));
  });

  test('a send the Provider rate-limits ends up in the log', () async {
    final engine = GetIt.I<SyncEngine>()..start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    a.sendFailure = RateLimitFailure(retryAfter: h.clock.now().add(const Duration(minutes: 5)));
    await engine.send('a', _message);
    h.clock.advance(sendWindow);
    await pumpEventQueue();
    expect(await h.errorLog.read(), contains('[send a] RateLimitFailure'));
  });

  test('a Bozza the Provider does not save ends up in the log', () async {
    final engine = GetIt.I<SyncEngine>();
    await engine.syncAll();
    await engine.saveDraft('a', _message);
    a.saveDraftFailure = const UnexpectedFailure('forwarded attachment gone');
    await engine.flushDrafts('a');
    expect(await h.errorLog.read(), contains('[draft replay a] UnexpectedFailure(forwarded attachment gone)'));
  });

  test('offline is not an error: nothing in the log', () async {
    a.goOffline();
    await GetIt.I<SyncEngine>().syncAll();
    expect(await h.errorLog.read(), isEmpty);
  });

  group('a sync that keeps failing offline (#252)', () {
    Future<void> failTimes(int n) async {
      for (var i = 0; i < n; i++) {
        await GetIt.I<SyncEngine>().syncAll();
      }
    }

    test('with the network up, the third failure in a row ends up in the log, once', () async {
      a.goOffline();
      await failTimes(2);
      expect(await h.errorLog.read(), isEmpty, reason: 'a failure or two may just be the network');
      await failTimes(4);
      final log = await h.errorLog.read();
      expect(log, contains('[sync gmail, 3 di fila] OfflineFailure'));
      expect('di fila'.allMatches(log), hasLength(1), reason: 'once per streak, not at every poll');
    });

    test('a sync that works ends the streak: the next one is logged again', () async {
      a.goOffline();
      await failTimes(3);
      a.goOnline();
      await failTimes(1);
      a.goOffline();
      await failTimes(3);
      expect('di fila'.allMatches(await h.errorLog.read()), hasLength(2));
    });

    test('with the device offline, nothing', () async {
      a.goOffline();
      h.connectivity.online = false;
      await failTimes(5);
      expect(await h.errorLog.read(), isEmpty);
    });
  });

  test('messages a sync left behind end up in the log, with the reason', () async {
    await GetIt.I<SyncEngine>().syncAll();
    a
      ..deliver(msg('1'))
      ..deferredIds = ['1', '2']
      ..deferred = const OfflineFailure(detail: 'GET messages/*: no answer', stalled: true);
    await GetIt.I<SyncEngine>().syncAll();
    expect(
      await h.errorLog.read(),
      contains('[sync gmail, 2 messaggi rimandati] OfflineFailure(GET messages/*: no answer)'),
    );
  });

  group('what makes a slow Gmail sync visible (#322)', () {
    test('a sync over the threshold is logged with its duration, never one under it', () async {
      final engine = GetIt.I<SyncEngine>();
      a.hold = Completer<void>();
      var sync = engine.syncAll();
      await pumpEventQueue();
      h.clock.advance(const Duration(seconds: 10));
      a.hold!.complete();
      await sync;
      expect(await h.errorLog.read(), isEmpty);

      a.hold = Completer<void>();
      sync = engine.syncAll();
      await pumpEventQueue();
      h.clock.advance(const Duration(seconds: 45));
      a.hold!.complete();
      await sync;
      expect(await h.errorLog.read(), contains('[sync gmail, lenta] 45 s'));
    });

    test('a rate limit pause is logged when it starts and when it ends', () async {
      final engine = GetIt.I<SyncEngine>();
      a.rateLimit(retryAfter: h.clock.now().add(const Duration(minutes: 5)));
      await engine.syncAll();
      final started = await h.errorLog.read();
      expect(started, contains('[sync gmail, pausa rate limit] inizio'));
      expect(started, isNot(contains('fine')));

      a.rateLimit(on: false);
      await engine.syncAll();
      expect(await h.errorLog.read(), isNot(contains('fine')), reason: 'still paused');
      h.clock.advance(const Duration(minutes: 6));
      await engine.syncAll();
      expect(await h.errorLog.read(), contains('[sync gmail, pausa rate limit] fine'));
    });
  });
}
