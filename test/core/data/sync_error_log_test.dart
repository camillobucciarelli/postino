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
    expect(await h.errorLog.read(), contains('[label replay a] RejectedFailure(Etichetta sparita)'));
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

  test('offline is not an error: nothing in the log', () async {
    a.goOffline();
    await GetIt.I<SyncEngine>().syncAll();
    expect(await h.errorLog.read(), isEmpty);
  });
}
