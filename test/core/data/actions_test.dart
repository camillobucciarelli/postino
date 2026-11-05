import 'dart:async';

// Azioni through the offline queue with the expected value, and the Conflitti (#144, ADR 0008): on the seam of the
// fake Provider, with the real database, sync engine and queue under it.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/conflict.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void main() {
  late Harness h;
  late FakeMailProvider a;
  late SyncEngine engine;

  Future<Message> here(String id) async =>
      (await getIt<InboxRepository>().watchConversation('a', 't-$id').first).single.message;
  Future<Message> there(String id) async => switch (await a.initialSync()) {
    Ok(:final value) => value.messages.singleWhere((m) => m.id == id),
    Err(:final failure) => fail('$failure'),
  };
  Future<List<IntentRow>> queued() => getIt<PostinoDatabase>().select(getIt<PostinoDatabase>().intents).get();
  Future<List<Conflict>> conflicts() => getIt<InboxRepository>().watchConflicts().first;
  Placement placement(Message m) => valueOf(m, placementAttribute) as Placement;

  setUp(() async {
    h = await Harness.create();
    a = (await h.addAccount('a'))..deliver(msg('1'));
    engine = getIt<SyncEngine>();
    await engine.syncAll();
  });

  test('an Azione offline is in the database at once and on the Provider once back online', () async {
    a.goOffline();
    await engine.act('a', ['1'], const Archive());
    await engine.act('a', ['1'], const Star());
    expect(placement(await here('1')), Placement.archive);
    expect((await here('1')).isStarred, isTrue);
    expect(await getIt<InboxRepository>().watchUnifiedInbox().first, isEmpty, reason: 'the list updates offline');

    a.goOnline();
    await engine.syncAll();
    expect(placement(await there('1')), Placement.archive);
    expect((await there('1')).isStarred, isTrue);
    expect(await queued(), isEmpty);
  });

  test('two Azioni on the same attribute are one voce: the last wanted value, the expected one of the first', () async {
    a.goOffline();
    await engine.act('a', ['1'], const Archive());
    await engine.act('a', ['1'], const Delete());
    final voce = (await queued()).single;
    expect((voce.attribute, voce.wanted, voce.expected), (placementAttribute, 'trash', 'inbox'));

    a.goOnline();
    await engine.syncAll();
    expect(a.actionCalls.map((c) => (c.$2, c.$3)), [(const Delete(), Placement.inbox)]);
    expect(placement(await there('1')), Placement.trash);
  });

  group('changed elsewhere', () {
    test('the same attribute: a Conflitto, the local version stays and the voce is not retried', () async {
      a.goOffline();
      await engine.act('a', ['1'], const Archive());
      a
        ..changeElsewhere('1', placementAttribute, Placement.trash)
        ..goOnline();
      await engine.syncAll();

      expect(await conflicts(), [
        const Conflict(accountId: 'a', messageId: '1', local: Archive(), provider: Placement.trash),
      ]);
      expect(await queued(), isEmpty);
      expect(placement(await there('1')), Placement.trash, reason: 'nothing written on the Provider');
      expect(
        placement(await here('1')),
        Placement.archive,
        reason: 'the sync brought the Provider value, the local one wins',
      );

      await engine.syncAll();
      expect(a.actionCalls, hasLength(1));
    });

    test('the same attribute, done and undone here meanwhile: a Conflitto with the value from elsewhere', () async {
      a.goOffline();
      await engine.act('a', ['1'], const MarkRead());
      await engine.act('a', ['1'], const MarkUnread());
      a
        ..changeElsewhere('1', readAttribute, true)
        ..goOnline();
      await engine.syncAll();
      expect(await conflicts(), [const Conflict(accountId: 'a', messageId: '1', local: MarkUnread(), provider: true)]);
      expect((await here('1')).isRead, isFalse);
    });

    test('another attribute: no Conflitto, both changes stay', () async {
      a.goOffline();
      await engine.act('a', ['1'], const Archive());
      a
        ..changeElsewhere('1', starredAttribute, true)
        ..goOnline();
      await engine.syncAll();
      expect(await conflicts(), isEmpty);
      expect(placement(await there('1')), Placement.archive);
      expect((await there('1')).isStarred, isTrue);
      expect((await here('1')).isStarred, isTrue);
    });

    test('the same way: the Provider has the wanted value already, no Conflitto', () async {
      a.goOffline();
      await engine.act('a', ['1'], const Archive());
      a
        ..changeElsewhere('1', placementAttribute, Placement.archive)
        ..goOnline();
      await engine.syncAll();
      expect(await conflicts(), isEmpty);
      expect(await queued(), isEmpty);
    });
  });

  test('a message gone from the Provider: the voce is dropped without a Conflitto nor a log line', () async {
    a.goOffline();
    await engine.act('a', ['1'], const Star());
    a
      ..removeRemotely('1')
      ..goOnline();
    await engine.syncAll();
    expect(await queued(), isEmpty);
    expect(await conflicts(), isEmpty);
    expect(await h.errorLog.read(), isNot(contains('action replay')));
  });

  test('Elimina never meets a Conflitto, whatever changed elsewhere', () async {
    a.goOffline();
    await engine.act('a', ['1'], const Delete());
    a
      ..changeElsewhere('1', placementAttribute, Placement.archive)
      ..goOnline();
    await engine.syncAll();
    expect(await conflicts(), isEmpty);
    expect(placement(await there('1')), Placement.trash);
  });

  test('Da ricollegare: the replay waits, the mail stays readable and Azioni queue; the Conflitti come after the '
      'reconnection', () async {
    a.breakAuth();
    await engine.syncAll();
    final store = getIt<MailStore>();
    expect((await store.accounts()).single.status, AccountStatus.daRicollegare);

    await engine.act('a', ['1'], const Archive());
    expect(placement(await here('1')), Placement.archive);
    expect(a.actionCalls, isEmpty);
    expect(await queued(), hasLength(1));
    a
      ..restoreAuth()
      ..changeElsewhere('1', placementAttribute, Placement.trash);
    await engine.syncAll();
    expect(await conflicts(), isEmpty, reason: 'no replay while Da ricollegare');

    await store.setStatus('a', AccountStatus.attivo);
    await engine.syncAll();
    expect((await conflicts()).single.provider, Placement.trash);
  });

  group('resolving a Conflitto', () {
    setUp(() async {
      a.goOffline();
      await engine.act('a', ['1'], const Archive());
      a
        ..changeElsewhere('1', placementAttribute, Placement.trash)
        ..goOnline();
      await engine.syncAll();
      expect(await conflicts(), hasLength(1));
    });

    test('«tieni la mia»: the Provider gets the local value', () async {
      await engine.resolveConflict((await conflicts()).single, keepMine: true);
      expect(placement(await there('1')), Placement.archive);
      expect(await conflicts(), isEmpty);
      expect(await queued(), isEmpty);
    });

    test('«tieni la mia» offline: queued, forced on the Provider once back online', () async {
      a.goOffline();
      await engine.resolveConflict((await conflicts()).single, keepMine: true);
      expect(await conflicts(), isEmpty);
      a.goOnline();
      await engine.syncAll();
      expect(placement(await there('1')), Placement.archive);
      expect(await queued(), isEmpty);
    });

    test('«tieni quella del Provider»: the database has it, nothing stays queued', () async {
      await engine.resolveConflict((await conflicts()).single, keepMine: false);
      expect(placement(await here('1')), Placement.trash);
      expect(await conflicts(), isEmpty);
      expect(await queued(), isEmpty);
      expect(a.actionCalls, hasLength(1));
    });

    test('a new Azione on the attribute closes it, expecting the Provider value', () async {
      await engine.act('a', ['1'], const Archive());
      expect(await conflicts(), isEmpty);
      expect(placement(await there('1')), Placement.archive);
    });
  });

  group('«trattenuta» during the Annulla window', () {
    const window = Duration(seconds: 5);

    test('in the database at once, on the Provider only once the window ends', () async {
      final running = engine..start();
      addTearDown(running.stop);
      await engine.act('a', ['1'], const Archive(), hold: window);
      expect(placement(await here('1')), Placement.archive);
      await engine.syncAll();
      expect(a.actionCalls, isEmpty);

      h.clock.advance(window);
      await pumpEventQueue();
      expect(placement(await there('1')), Placement.archive);
      expect(await queued(), isEmpty);
    });

    test('Annulla takes it back: out of the queue, the message as before', () async {
      await engine.act('a', ['1'], const Archive(), hold: window);
      expect(await engine.cancelAction('a', ['1'], const Archive()), isTrue);
      expect(placement(await here('1')), Placement.inbox);
      expect(await queued(), isEmpty);
      expect(await engine.cancelAction('a', ['1'], const Archive()), isFalse);
    });

    test('Annulla over an Azione queued before brings that one back', () async {
      a.goOffline();
      await engine.act('a', ['1'], const Archive());
      await engine.act('a', ['1'], const Delete(), hold: window);
      expect(await engine.cancelAction('a', ['1'], const Delete()), isTrue);
      expect(placement(await here('1')), Placement.archive);
      final voce = (await queued()).single;
      expect((voce.wanted, voce.expected, voce.heldUntil), ('archive', 'inbox', null));
    });

    test('the Annulla of an earlier Azione does not take back a later one', () async {
      await engine.act('a', ['1'], const Archive(), hold: window);
      await engine.act('a', ['1'], const Delete(), hold: window);
      expect(await engine.cancelAction('a', ['1'], const Archive()), isFalse);
      expect(placement(await here('1')), Placement.trash);
    });

    test('once the window ended, Annulla takes nothing back, also when the replay could not run', () async {
      await getIt<MailStore>().setStatus('a', AccountStatus.daRicollegare);
      await engine.act('a', ['1'], const Archive(), hold: window);
      h.clock.advance(window);
      expect(await engine.cancelAction('a', ['1'], const Archive()), isFalse);
      expect(placement(await here('1')), Placement.archive);
    });

    test('Annulla of an Azione over a Conflitto brings the Conflitto back, with its local version', () async {
      a
        ..goOffline()
        ..changeElsewhere('1', placementAttribute, Placement.trash);
      await engine.act('a', ['1'], const Star());
      await engine.act('a', ['1'], const Archive());
      a.goOnline();
      await engine.syncAll();
      final open = await conflicts();
      expect(open, hasLength(1));

      await engine.act('a', ['1'], const Delete(), hold: window);
      expect(await engine.cancelAction('a', ['1'], const Delete()), isTrue);
      expect(await conflicts(), open);
      expect(placement(await here('1')), Placement.archive);
    });
  });

  test('changed again elsewhere while in Conflitto: «tieni quella del Provider» brings the latest value', () async {
    a.goOffline();
    await engine.act('a', ['1'], const Archive());
    a
      ..changeElsewhere('1', placementAttribute, Placement.trash)
      ..goOnline();
    await engine.syncAll();
    a.changeElsewhere('1', placementAttribute, Placement.inbox);
    await engine.syncAll();
    final open = (await conflicts()).single;
    expect(open.provider, Placement.inbox);
    expect(placement(await here('1')), Placement.archive, reason: 'the local version stays while it is open');

    await engine.resolveConflict(open, keepMine: false);
    expect(placement(await here('1')), Placement.inbox);
  });

  test('changed elsewhere to the local value while in Conflitto: it closes, nothing queued', () async {
    a.goOffline();
    await engine.act('a', ['1'], const Archive());
    a
      ..changeElsewhere('1', placementAttribute, Placement.trash)
      ..goOnline();
    await engine.syncAll();
    expect(await conflicts(), hasLength(1));

    a.changeElsewhere('1', placementAttribute, Placement.archive);
    await engine.syncAll();
    expect(await conflicts(), isEmpty);
    expect(await queued(), isEmpty);
    expect(placement(await here('1')), Placement.archive);
  });

  test('a message with a Conflitto gone from the Provider: the Conflitto closes', () async {
    a.goOffline();
    await engine.act('a', ['1'], const Archive());
    a
      ..changeElsewhere('1', placementAttribute, Placement.trash)
      ..goOnline();
    await engine.syncAll();
    expect(await conflicts(), hasLength(1));

    a.removeRemotely('1');
    await engine.syncAll();
    expect(await conflicts(), isEmpty);
  });

  test('«tieni quella del Provider» while the replay sends the voci before: its voce is not sent', () async {
    a.deliver(msg('2'));
    await engine.syncAll();
    a.goOffline();
    await engine.act('a', ['2'], const Archive());
    a
      ..changeElsewhere('2', placementAttribute, Placement.trash)
      ..goOnline();
    await engine.syncAll();
    final open = (await conflicts()).single;
    // Offline: a read sent first, then a new Archivia over the Conflitto.
    a.goOffline();
    await engine.act('a', ['1'], const MarkRead());
    await engine.act('a', ['2'], const Archive());
    a.goOnline();

    final sending = a.holdRead = Completer<void>();
    final sync = engine.syncAll();
    await pumpEventQueue();
    await engine.resolveConflict(open, keepMine: false);
    a.holdRead = null;
    sending.complete();
    await sync;

    expect(placement(await there('2')), Placement.trash, reason: 'the choice is not overwritten');
    expect(placement(await here('2')), Placement.trash);
    expect(await conflicts(), isEmpty);
    expect(await queued(), isEmpty);
  });

  test('an Azione undone while it was being sent: no Conflitto with its own write', () async {
    final sending = a.holdRead = Completer<void>();
    final read = engine.act('a', ['1'], const MarkRead());
    await pumpEventQueue();
    final unread = engine.act('a', ['1'], const MarkUnread());
    await pumpEventQueue();
    a.holdRead = null;
    sending.complete();
    await (read, unread).wait;
    expect(await conflicts(), isEmpty);
    expect((await there('1')).isRead, isFalse);
    expect(await queued(), isEmpty);
  });
}
