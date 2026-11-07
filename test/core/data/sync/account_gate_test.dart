import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/main.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/harness.dart';

void main() {
  late Harness h;
  late FakeMailProvider a;

  Future<List<String>> inbox() async =>
      [for (final e in await getIt<InboxRepository>().watchUnifiedInbox().first) '${e.account.id}:${e.message.id}']
        ..sort();

  setUp(() async {
    h = await Harness.create();
    a = (await h.addAccount('a'))
      ..deliver(msg('1'))
      ..deliver(msg('2'));
    (await h.addAccount('b')).deliver(msg('1'));
    await GetIt.I<SyncEngine>().syncAll();
  });

  test('a rate-limited sync is retried on the next poll, even with the change signal up', () async {
    final engine = GetIt.I<SyncEngine>()..start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    a
      ..rateLimit()
      ..deliver(msg('3')); // change signal -> sync -> RateLimitFailure
    await pumpEventQueue();
    expect(await inbox(), isNot(contains('a:3')));

    a.rateLimit(on: false);
    h.clock.advance(pollEvery);
    await pumpEventQueue();
    expect(await inbox(), contains('a:3'));
  });

  test('a block with retryAfter pauses polls and signals until then', () async {
    final engine = GetIt.I<SyncEngine>()..start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    final until = h.clock.now().add(const Duration(minutes: 5));
    a
      ..rateLimit(retryAfter: until)
      ..deliver(msg('3')); // signal -> sync -> RateLimitFailure with retryAfter
    await pumpEventQueue();
    final syncs = a.initialSyncs;

    a
      ..rateLimit(on: false)
      ..deliver(msg('4')); // signal while paused: skipped
    h.clock.advance(pollEvery); // poll while paused: skipped
    await pumpEventQueue();
    expect(await inbox(), isNot(contains('a:3')));
    expect(a.initialSyncs, syncs);

    h.clock.advance(const Duration(minutes: 5));
    await pumpEventQueue();
    expect(await inbox(), containsAll(['a:3', 'a:4']));
  });
}
