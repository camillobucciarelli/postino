import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void main() {
  late Harness h;
  late FakeMailProvider a, b;

  Future<List<String>> inbox() async => [
    for (final e in await getIt<InboxRepository>().watchUnifiedInbox().first)
      '${e.account.id}:${e.message.id}',
  ]..sort();

  setUp(() async {
    h = await Harness.create();
    a = (await h.addAccount('a'))
      ..deliver(msg('1'))
      ..deliver(msg('2'));
    b = (await h.addAccount('b'))..deliver(msg('1'));
    await GetIt.I<SyncEngine>().syncAll();
  });

  test('opening a Conversazione during a sync: the older in-flight batch does not undo the read', () async {
    final engine = GetIt.I<SyncEngine>();
    final slow = a.hold = Completer<void>();
    a.deliver(msg('1')); // still unread in the batch the sync is fetching
    final sync = engine.syncAll();
    await pumpEventQueue();

    await engine.openConversation('a', 't-1');
    a.hold = null;
    slow.complete();
    await sync;

    final [(:message, body: _)] = await getIt<InboxRepository>()
        .watchConversation('a', 't-1')
        .first;
    expect(message.isRead, isTrue);
    expect(a.readCalls.map((c) => (c.$1.join(), c.$2)), [('1', true)]);
  });

  test('a message removed on the Provider disappears after re-sync', () async {
    expect(await inbox(), ['a:1', 'a:2', 'b:1']);
    a.removeRemotely('2');
    await GetIt.I<SyncEngine>().syncAll();
    expect(await inbox(), ['a:1', 'b:1']);
  });

  test('an initial sync that fails mid-way keeps the stored pages, no cursor, and the next run completes', () async {
    final c = (await h.addAccount('c'))
      ..pageSize = 2
      ..failAfterPages = 1;
    for (final id in ['1', '2', '3', '4']) {
      c.deliver(msg(id));
    }
    final store = GetIt.I<MailStore>();
    await GetIt.I<SyncEngine>().syncAll();
    // The first page is in the DB although the second was never fetched.
    expect((await inbox()).where((e) => e.startsWith('c:')), hasLength(2));
    expect(await store.cursor('c'), isNull);

    c.failAfterPages = null;
    await GetIt.I<SyncEngine>().syncAll();
    expect((await inbox()).where((e) => e.startsWith('c:')), hasLength(4));
    expect(await store.cursor('c'), isNotNull);
  });

  test('a failed sync deletes nothing', () async {
    a.removeRemotely('2');
    a.goOffline();
    await GetIt.I<SyncEngine>().syncAll();
    expect(await inbox(), ['a:1', 'a:2', 'b:1']);
  });

  test('other Accounts are untouched', () async {
    b.removeRemotely('1');
    a.goOffline();
    await GetIt.I<SyncEngine>().syncAll();
    expect(await inbox(), ['a:1', 'a:2']);
  });

  test(
    'an empty initial snapshot clears the Account cache, labels included',
    () async {
      a
        ..removeRemotely('1')
        ..removeRemotely('2')
        ..expireCursors(); // forces the initial sync, i.e. a full snapshot
      await GetIt.I<SyncEngine>().syncAll();
      expect(await inbox(), ['b:1']);
      final db = GetIt.I<PostinoDatabase>();
      for (final table in ['messages', 'message_labels']) {
        expect(
          await db
              .customSelect("SELECT 1 FROM $table WHERE account_id = 'a'")
              .get(),
          isEmpty,
        );
      }
    },
  );

  test(
    'a snapshot larger than the SQL variable limit still reconciles',
    () async {
      for (var i = 0; i < 40000; i++) {
        a.deliver(msg('big$i'));
      }
      await GetIt.I<SyncEngine>().syncAll();
      a
        ..removeRemotely('1')
        ..expireCursors(); // full snapshot again
      await GetIt.I<SyncEngine>().syncAll();
      expect(
        (await inbox()).length,
        40000 + 1 + 1,
      ); // a: 2 + big - '1', plus b:1
    },
  );

  test(
    'after the first sync, only the changes since the saved cursor are fetched',
    () async {
      a.deliver(msg('3'));
      await GetIt.I<SyncEngine>().syncAll();
      expect(a.initialSyncs, 1);
      expect(a.lastIncremental!.messages.map((m) => m.id), ['3']);
      expect(await inbox(), ['a:1', 'a:2', 'a:3', 'b:1']);
    },
  );

  test(
    'an expired cursor redoes the initial sync, which drops what is gone',
    () async {
      a
        ..removeRemotely('2')
        ..deliver(msg('3'))
        ..expireCursors();
      await GetIt.I<SyncEngine>().syncAll();
      expect(a.initialSyncs, 2);
      expect(await inbox(), ['a:1', 'a:3', 'b:1']);
    },
  );

  test(
    'the inbox bodies are stored with the sync, and removed with their message',
    () async {
      final db = GetIt.I<PostinoDatabase>();
      Future<List<String>> bodies() async => [
        for (final r
            in await db
                .customSelect(
                  "SELECT body FROM bodies WHERE account_id = 'a' ORDER BY message_id",
                )
                .get())
          r.read<String>('body'),
      ];
      expect(await bodies(), ['Corpo di 1', 'Corpo di 2']);
      a.removeRemotely('2');
      await GetIt.I<SyncEngine>().syncAll();
      expect(await bodies(), ['Corpo di 1']);
    },
  );

  test('a rate-limited sync is retried on the next poll, even with the change signal up', () async {
    final engine = GetIt.I<SyncEngine>()..start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    a.rateLimit();
    a.deliver(msg('3')); // change signal -> sync -> RateLimitFailure
    await pumpEventQueue();
    expect(await inbox(), isNot(contains('a:3')));

    a.rateLimit(false);
    h.clock.advance(pollEvery);
    await pumpEventQueue();
    expect(await inbox(), contains('a:3'));
  });

  test('a block with retryAfter pauses polls and signals until then', () async {
    final engine = GetIt.I<SyncEngine>()..start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    final until = h.clock.now().add(const Duration(minutes: 5));
    a.rateLimit(true, until);
    a.deliver(msg('3')); // signal -> sync -> RateLimitFailure with retryAfter
    await pumpEventQueue();
    final syncs = a.initialSyncs;

    a.rateLimit(false);
    a.deliver(msg('4')); // signal while paused: skipped
    h.clock.advance(pollEvery); // poll while paused: skipped
    await pumpEventQueue();
    expect(await inbox(), isNot(contains('a:3')));
    expect(a.initialSyncs, syncs);

    h.clock.advance(const Duration(minutes: 5));
    await pumpEventQueue();
    expect(await inbox(), containsAll(['a:3', 'a:4']));
  });
}
