// Notifiche immediate (#214): the service keeps the app's engine alive with Postino closed, so the sync that runs
// there is the app's SyncEngine. With a fake Provider: a change signalled by IDLE syncs and notifies at once, without
// the poll; without a signal (Microsoft in v1, or IDLE down) the 60 s poll does it; the periodic task, still scheduled
// as a safety net, never syncs an Account next to the engine.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/background_sync.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void main() {
  late Harness h;
  late SyncEngine engine;

  setUp(() async {
    h = await Harness.create();
    engine = getIt<SyncEngine>();
  });

  tearDown(() => engine.stop());

  /// The engine started with the Account [id] synced once, as the service finds it.
  Future<FakeMailProvider> started(String id, {ProviderKind provider = ProviderKind.gmail, bool signal = true}) async {
    final a = await h.addAccount(id, provider: provider);
    // Microsoft in v1 has no IDLE: its change signal is always down (ADR 0008).
    if (!signal) a.dropSignal();
    a.deliver(msg('$id-old'), signal: false);
    engine.start();
    await engine.syncAll();
    await pumpEventQueue();
    return a;
  }

  List<String> notified() => [for (final n in h.notifications.shown) n.subject];

  test('a change signalled by IDLE: synced and notified at once, the poll not waited for', () async {
    final a = await started('a');
    final calls = a.syncCalls;

    a.deliver(msg('a-2', subject: 'Subito'));
    await pumpEventQueue();

    expect(notified(), ['Subito']);
    expect(a.syncCalls, calls + 1);
  });

  test('a Microsoft Account (no IDLE in v1): nothing before the poll, notified at the 60 s poll', () async {
    final a = await started('m', provider: ProviderKind.microsoft, signal: false);

    a.deliver(msg('m-2', subject: 'Da Outlook'), signal: false);
    h.clock.advance(pollEvery - const Duration(seconds: 1));
    await pumpEventQueue();
    expect(notified(), isEmpty);

    h.clock.advance(const Duration(seconds: 1));
    await pumpEventQueue();
    expect(notified(), ['Da Outlook']);
  });

  test('IDLE down: the poll every 60 s until it comes back, then the signal again', () async {
    final a = await started('a');
    a.dropSignal();
    await pumpEventQueue();

    a.deliver(msg('a-2', subject: 'Durante il buco'));
    await pumpEventQueue();
    expect(notified(), isEmpty);
    h.clock.advance(pollEvery);
    await pumpEventQueue();
    expect(notified(), ['Durante il buco']);

    a.deliver(msg('a-3', subject: 'Ancora giù'));
    h.clock.advance(pollEvery);
    await pumpEventQueue();
    expect(notified(), ['Durante il buco', 'Ancora giù']);

    // Back up: what changed meanwhile, then each change at once again.
    a
      ..deliver(msg('a-4', subject: 'Al ritorno'), signal: false)
      ..restoreSignal();
    await pumpEventQueue();
    expect(notified().last, 'Al ritorno');
    a.deliver(msg('a-5', subject: 'Di nuovo subito'));
    await pumpEventQueue();
    expect(notified().last, 'Di nuovo subito');
  });

  test('the periodic task with the engine alive: it asks the engine, the Account never syncs twice at once', () async {
    final a = await started('a');
    final calls = a.syncCalls;
    final slow = a.hold = Completer<void>();

    a.deliver(msg('a-2', subject: 'Uno'));
    await pumpEventQueue();
    expect(a.syncCalls, calls + 1);

    // The safety net fires while the engine's sync is still on the network.
    final task = runSyncTask();
    await pumpEventQueue();
    expect(a.syncCalls, calls + 1, reason: 'the task does not sync next to the engine');

    a.hold = null;
    slow.complete();
    expect(await task, isTrue);
    await pumpEventQueue();
    expect(notified(), ['Uno']);
    expect(engine.syncAll(), completes);
  });
}
