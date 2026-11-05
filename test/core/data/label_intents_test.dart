// Etichette through the offline queue (#105, ADR 0008): here at once, on the Provider when it can.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _viaggi = 'Label_12';
const _lavoro = Label(id: 'Label_7', name: 'Lavoro', kind: LabelKind.etichetta);

void main() {
  late Harness h;
  late FakeMailProvider a;
  late SyncEngine engine;

  Future<List<String>> here(String id) async =>
      (await getIt<InboxRepository>().watchConversation('a', 't-$id').first).single.message.labelIds;
  Future<List<String>> there(String id) async => switch (await a.initialSync()) {
    Ok(:final value) => value.messages.singleWhere((m) => m.id == id).labelIds,
    Err(:final failure) => fail('$failure'),
  };
  Future<List<LabelIntentRow>> queued() {
    final db = getIt<PostinoDatabase>();
    return db.select(db.labelIntents).get();
  }

  Future<List<MessageLabelRow>> labelRows(String id) {
    final db = getIt<PostinoDatabase>();
    return (db.select(db.messageLabels)..where((t) => t.messageId.equals(id))).get();
  }

  setUp(() async {
    h = await Harness.create();
    a = (await h.addAccount('a'))..deliver(msg('1'));
    engine = getIt<SyncEngine>();
    await engine.syncAll();
  });

  test('an Etichetta added offline is on the message here at once, and on the Provider once back online', () async {
    a.goOffline();
    await engine.setLabel('a', '1', _viaggi, add: true);
    expect(await here('1'), contains(_viaggi));
    expect(await queued(), hasLength(1));

    a.goOnline();
    expect(await there('1'), isNot(contains(_viaggi)));
    await engine.syncAll();
    expect(await there('1'), contains(_viaggi));
    expect(await here('1'), contains(_viaggi));
    expect(await queued(), isEmpty);
  });

  test('added then removed before the replay: the intents merge and the last one wins', () async {
    a.goOffline();
    await engine.setLabel('a', '1', _viaggi, add: true);
    await engine.setLabel('a', '1', _viaggi, add: false);
    a.goOnline();
    await engine.syncAll();
    expect(a.labelCalls, [('1', _viaggi, false)]);
    expect(await here('1'), isNot(contains(_viaggi)));
    expect(await there('1'), isNot(contains(_viaggi)));
  });

  test('repeating an intent does not change the result', () async {
    await engine.setLabel('a', '1', _viaggi, add: true);
    await engine.setLabel('a', '1', _viaggi, add: true);
    expect(a.labelCalls, hasLength(2));
    expect((await there('1')).where((l) => l == _viaggi), hasLength(1));
    expect((await here('1')).where((l) => l == _viaggi), hasLength(1));
    expect(await queued(), isEmpty);
  });

  test('a sync before the replay does not undo what was done here', () async {
    a
      ..deliver(msg('2', labelIds: const [inboxLabelId, _viaggi]))
      ..setLabelFailure = const OfflineFailure();
    await engine.syncAll();
    await engine.setLabel('a', '1', _viaggi, add: true);
    await engine.setLabel('a', '2', _viaggi, add: false);
    // Both change elsewhere: the sync brings them back with the Provider's labels.
    a
      ..deliver(msg('1', isRead: true))
      ..deliver(msg('2', isRead: true, labelIds: const [inboxLabelId, _viaggi]));
    await engine.syncAll();
    expect(await here('1'), contains(_viaggi));
    expect(await here('2'), isNot(contains(_viaggi)));

    a.setLabelFailure = null;
    await engine.syncAll();
    expect(await there('1'), contains(_viaggi));
    expect(await there('2'), isNot(contains(_viaggi)));
    expect(await queued(), isEmpty);
  });

  group(
    'no Conflitto: an Etichetta is on the message or not, so the Provider has the queued value or the wanted one',
    () {
      test('removed elsewhere too while the removal waited: replayed and dropped', () async {
        a.deliver(msg('1', labelIds: const [inboxLabelId, _viaggi]));
        await engine.syncAll();
        a.goOffline();
        await engine.setLabel('a', '1', _viaggi, add: false);
        a
          ..deliver(msg('1'))
          ..goOnline();
        await engine.syncAll();
        expect(a.labelCalls, [('1', _viaggi, false)]);
        expect(await here('1'), isNot(contains(_viaggi)));
        expect(await queued(), isEmpty);
      });

      test('another Etichetta added elsewhere meanwhile: both stay', () async {
        a.goOffline();
        await engine.setLabel('a', '1', _viaggi, add: true);
        a
          ..deliver(msg('1', labelIds: [inboxLabelId, _lavoro.id]))
          ..goOnline();
        await engine.syncAll();
        expect(await there('1'), containsAll([_viaggi, _lavoro.id]));
        expect(await here('1'), containsAll([_viaggi, _lavoro.id]));
      });

      test('the message deleted elsewhere: the intent is dropped in silence', () async {
        a.goOffline();
        await engine.setLabel('a', '1', _viaggi, add: true);
        a
          ..removeRemotely('1')
          ..goOnline();
        await engine.syncAll();
        expect(await queued(), isEmpty);
        expect(await getIt<InboxRepository>().watchConversation('a', 't-1').first, isEmpty);
        expect(await labelRows('1'), isEmpty, reason: 'no orphan label on the removed message');
      });

      test('refused by the Provider (an Etichetta deleted elsewhere): dropped, and undone here', () async {
        a.deliver(msg('2', labelIds: const [inboxLabelId, _viaggi]));
        await engine.syncAll();
        a.setLabelFailure = const RejectedFailure('no such label');
        await engine.setLabel('a', '1', _viaggi, add: true);
        await engine.setLabel('a', '2', _viaggi, add: false);
        expect(await queued(), isEmpty);
        expect(await here('1'), isNot(contains(_viaggi)));
        expect(await here('2'), contains(_viaggi));
      });
    },
  );

  test('a passing failure stops the Etichette replay at the first intent: the rest waits for the next one', () async {
    a.deliver(msg('2'));
    await engine.syncAll();
    a.goOffline();
    await engine.setLabel('a', '1', _viaggi, add: true);
    await engine.setLabel('a', '2', _viaggi, add: true);
    a
      ..goOnline()
      ..setLabelFailure = const RateLimitFailure();
    await engine.flushDrafts('a');
    expect(a.labelCalls, hasLength(1));
    expect(await queued(), hasLength(2));
  });

  test('a Conversazione\'s Etichetta replays once for all its messages; a rate limit pauses the Account', () async {
    a
      ..deliver(msg('2'))
      ..deliver(msg('3'));
    await engine.syncAll();
    a.setLabelFailure = RateLimitFailure(retryAfter: h.clock.now().add(const Duration(minutes: 5)));
    await engine.setConversationLabel('a', ['1', '2', '3'], _viaggi, add: true);
    expect(a.labelCalls, hasLength(1));
    expect(await queued(), hasLength(3));
    // Paused: the next change is queued without calling the Provider again.
    await engine.setLabel('a', '1', _lavoro.id, add: true);
    expect(a.labelCalls, hasLength(1));
  });

  test('completeConversation brings the older messages and does not read the Conversazione', () async {
    a.deliverOutsideWindow(msg('old', conversationId: 't-1'));
    await engine.completeConversation('a', 't-1');
    final c = await getIt<InboxRepository>().watchConversation('a', 't-1').first;
    expect(c.map((m) => m.message.id), containsAll(['1', 'old']));
    expect(c.every((m) => !m.message.isRead), isTrue);
  });

  test('while the Provider\'s pause holds, completeConversation and openConversation do not ask the Provider; '
      'the Etichetta goes on the local messages', () async {
    a
      ..deliverOutsideWindow(msg('old', conversationId: 't-1'))
      ..rateLimit(retryAfter: h.clock.now().add(const Duration(minutes: 5)));
    await engine.syncAll();
    a.rateLimit(on: false);

    expect(await engine.completeConversation('a', 't-1'), isA<Err<void>>());
    expect(await engine.openConversation('a', 't-1'), isA<Err<void>>());
    final c = await getIt<InboxRepository>().watchConversation('a', 't-1').first;
    // The Provider would have brought the older message.
    expect(c.map((m) => m.message.id), ['1']);

    await engine.setConversationLabel('a', ['1'], _viaggi, add: true);
    expect(await here('1'), contains(_viaggi));
    expect(a.labelCalls, isEmpty);
  });

  test('while the Provider\'s pause holds: done here, queued, the Provider not called', () async {
    a.rateLimit(retryAfter: h.clock.now().add(const Duration(minutes: 5)));
    await engine.syncAll();
    a.rateLimit(on: false);
    await engine.setLabel('a', '1', _viaggi, add: true);
    expect(await here('1'), contains(_viaggi));
    expect(await queued(), hasLength(1));
    expect(a.labelCalls, isEmpty);
  });

  test('while Da ricollegare: done here, queued, the Provider not called', () async {
    await getIt<MailStore>().setStatus('a', AccountStatus.daRicollegare);
    await engine.setLabel('a', '1', _viaggi, add: true);
    expect(await here('1'), contains(_viaggi));
    expect(await queued(), hasLength(1));
    expect(a.labelCalls, isEmpty);
  });

  test(
    'a Conversazione\'s Etichetta is one batch: its messages show it all or none; on then off at once ends off',
    () async {
      final ids = [for (var i = 0; i < 50; i++) 'c$i'];
      for (final id in ids) {
        a.deliver(msg(id, conversationId: 't-big'));
      }
      await engine.syncAll();
      a.goOffline();
      Future<List<Message>> conversation() async => [
        for (final m in await getIt<InboxRepository>().watchConversation('a', 't-big').first) m.message,
      ];

      final adding = engine.setConversationLabel('a', ids, _viaggi, add: true);
      // As the picker does: the removal goes to the messages that show the Etichetta now.
      late List<Message> shown;
      do {
        shown = await conversation();
      } while (!shown.any((m) => m.labelIds.contains(_viaggi)));
      expect(shown.where((m) => !m.labelIds.contains(_viaggi)), isEmpty);
      final removing = engine.setConversationLabel(
        'a',
        [
          for (final m in shown)
            if (m.labelIds.contains(_viaggi)) m.id,
        ],
        _viaggi,
        add: false,
      );
      await Future.wait([adding, removing]);

      expect((await conversation()).where((m) => m.labelIds.contains(_viaggi)), isEmpty);
      final intents = (await queued()).where((i) => i.labelId == _viaggi);
      expect(intents, hasLength(50));
      expect(intents.every((i) => !i.added), isTrue);
    },
  );

  test('two batches called one after the other apply in that order', () async {
    final ids = [for (var i = 0; i < 50; i++) 'c$i'];
    for (final id in ids) {
      a.deliver(msg(id, conversationId: 't-big'));
    }
    await engine.syncAll();
    a.goOffline();
    await Future.wait([
      engine.setConversationLabel('a', ids, _viaggi, add: true),
      engine.setConversationLabel('a', ids, _viaggi, add: false),
    ]);
    final c = await getIt<InboxRepository>().watchConversation('a', 't-big').first;
    expect(c.where((m) => m.message.labelIds.contains(_viaggi)), isEmpty);
    expect((await queued()).where((i) => i.labelId == _viaggi).every((i) => !i.added), isTrue);
  });

  test('an intent replaced while the replay ran stays: only the replayed value leaves', () async {
    final store = getIt<MailStore>();
    await store.queueLabels('a', ['1'], _viaggi, add: true);
    await store.queueLabels('a', ['1'], _viaggi, add: false);
    await store.labelDone('a', '1', _viaggi, added: true);
    expect((await queued()).map((i) => i.added), [false]);
  });

  test('a created Etichetta is listed here at once; offline it is an Err and nothing is stored', () async {
    final created = await engine.createLabel('a', 'Fatture');
    expect(created, isA<Ok<Label>>());
    expect((await getIt<InboxRepository>().watchLabels('a').first).map((l) => l.name), ['Fatture', 'Viaggi']);

    a.goOffline();
    final offline = await engine.createLabel('a', 'Casa');
    expect(offline, isA<Err<Label>>().having((e) => e.failure, 'failure', isA<OfflineFailure>()));
    expect((await getIt<InboxRepository>().watchLabels('a').first).map((l) => l.name), ['Fatture', 'Viaggi']);
  });

  test('the incremental sync brings an Etichetta created elsewhere and drops one deleted elsewhere', () async {
    a.labels
      ..clear()
      ..add(_lavoro);
    await engine.syncAll();
    expect(a.initialSyncs, 1);
    expect(await getIt<InboxRepository>().watchLabels('a').first, [_lavoro]);
  });
}
