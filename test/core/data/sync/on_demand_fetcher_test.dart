import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/mail_store.dart';
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

  test('opening a Conversazione during a sync: the older in-flight batch does not undo the read', () async {
    final engine = GetIt.I<SyncEngine>();
    final slow = a.hold = Completer<void>();
    a.deliver(msg('1')); // still unread in the batch the sync is fetching
    final sync = engine.syncAll();
    await pumpEventQueue();

    // The hydration queues behind the sync; the read is local at once.
    final open = engine.openConversation('a', 't-1');
    await pumpEventQueue();
    a.hold = null;
    slow.complete();
    await (sync, open).wait;

    final [(:message, body: _)] = await getIt<InboxRepository>().watchConversation('a', 't-1').first;
    expect(message.isRead, isTrue);
    expect(a.readCalls.map((c) => (c.$1.join(), c.$2)), [('1', true)]);
  });

  test('a read that fails to reach the Provider is retried on the next poll, even with the change signal up and the mail syncing', () async {
    final engine = GetIt.I<SyncEngine>()..start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    a.failSetRead = true;
    await engine.openConversation('a', 't-1');
    a.deliver(msg('3')); // change signal -> sync: mail fetched, replay fails again
    await pumpEventQueue();
    expect(await inbox(), contains('a:3'));
    expect(a.readCalls, isEmpty);

    a.failSetRead = false;
    h.clock.advance(pollEvery);
    await pumpEventQueue();
    expect(a.readCalls.map((c) => (c.$1.join(), c.$2)), [('1', true)]);
  });

  test(
    'a Conversazione opened while another one\'s read is being sent is read on the Provider too, without a poll',
    () async {
      final engine = GetIt.I<SyncEngine>();
      final sending = a.holdRead = Completer<void>();
      final first = engine.openConversation('a', 't-1');
      await pumpEventQueue();
      expect(a.readCalls, isEmpty); // the read of t-1 is in flight

      final second = engine.openConversation('a', 't-2');
      await pumpEventQueue();
      a.holdRead = null;
      sending.complete();
      await (first, second).wait;

      expect(a.readCalls.map((c) => c.$1.join()), ['1', '2']);
      expect(await GetIt.I<MailStore>().pendingActions('a', h.clock.now()), isEmpty);
    },
  );

  test('a Conversazione snapshot fetched before a deletion does not bring the message back', () async {
    final engine = GetIt.I<SyncEngine>();
    final fetching = a.holdConversation = Completer<void>();
    final open = engine.openConversation('a', 't-2'); // snapshot still has 2
    await pumpEventQueue();

    a.removeRemotely('2');
    final sync = engine.syncAll();
    await pumpEventQueue();
    a.holdConversation = null;
    fetching.complete();
    await (open, sync).wait;

    expect(await inbox(), ['a:1', 'b:1']);
  });
}
