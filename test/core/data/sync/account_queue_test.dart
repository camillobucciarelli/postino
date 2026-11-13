import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/sync/intent_replayer.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/message.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/harness.dart';

void main() {
  late Harness h;
  late FakeMailProvider a;

  setUp(() async {
    h = await Harness.create();
    a = (await h.addAccount('a'))
      ..deliver(msg('1'))
      ..deliver(msg('2'));
    (await h.addAccount('b')).deliver(msg('1'));
    await GetIt.I<SyncEngine>().syncAll();
  });

  group('pull-to-refresh', () {
    test('during a running sync it queues no other and ends with it', () async {
      final engine = GetIt.I<SyncEngine>();
      final slow = a.hold = Completer<void>();
      final before = a.syncCalls;
      final sync = engine.syncAll();
      await pumpEventQueue();

      var refreshed = false;
      final refresh = engine.refresh().then((_) => refreshed = true);
      await pumpEventQueue();
      expect(refreshed, isFalse);

      a.hold = null;
      slow.complete();
      await (sync, refresh).wait;
      expect(a.syncCalls, before + 1);
    });

    test('it does not wait for the Bozze upload, which goes on after it', () async {
      final engine = GetIt.I<SyncEngine>();
      await engine.saveDraft(
        'a',
        const OutgoingMessage(messageId: '<d@example.com>', from: 'a@example.com', to: [], subject: 's', body: ''),
      );
      await engine.stop(); // no debounce timer: the upload is the sync's own
      h.clock.advance(draftDebounce);
      final uploading = a.holdDraft = Completer<void>();

      await engine.refresh();
      expect(a.draftCalls, isEmpty); // held in the upload, after the sync phase
      uploading.complete();
      await engine.syncAll();
      expect(a.draftCalls.map((c) => c.$1), ['<d@example.com>']);
    });

    test('a poll, IDLE or resume sync during a running one still queues another', () async {
      final engine = GetIt.I<SyncEngine>();
      final slow = a.hold = Completer<void>();
      final before = a.syncCalls;
      final first = engine.syncAll();
      await pumpEventQueue();
      final second = engine.syncAll();
      a.hold = null;
      slow.complete();
      await (first, second).wait;
      expect(a.syncCalls, before + 2);
    });

    Future<void> pendingDraft(SyncEngine engine) async {
      await engine.saveDraft(
        'a',
        const OutgoingMessage(messageId: '<d@example.com>', from: 'a@example.com', to: [], subject: 's', body: ''),
      );
      await engine.stop(); // no debounce timer: the upload is the sync's own
      h.clock.advance(draftDebounce);
    }

    test('during the Bozze upload of a running sync it ends at once, with no other sync', () async {
      final engine = GetIt.I<SyncEngine>();
      await pendingDraft(engine);
      final uploading = a.holdDraft = Completer<void>();
      final before = a.syncCalls;
      final sync = engine.syncAll();
      while (a.draftHeld == null) {
        await pumpEventQueue();
      }

      await engine.refresh();
      expect(a.syncCalls, before + 1);
      uploading.complete();
      await sync;
      expect(a.syncCalls, before + 1);
    });

    test('it joins a sync queued behind a Conversazione opening', () async {
      final engine = GetIt.I<SyncEngine>();
      final fetching = a.holdConversation = Completer<void>();
      final open = engine.openConversation('a', 't-1');
      await pumpEventQueue();
      final before = a.syncCalls;
      final queued = engine.syncAll();
      final refresh = engine.refresh();
      a.holdConversation = null;
      fetching.complete();
      await (open, queued, refresh).wait;
      expect(a.syncCalls, before + 1);
    });

    test('a sync that makes the Account Da ricollegare uploads no Bozza after it', () async {
      final engine = GetIt.I<SyncEngine>();
      await pendingDraft(engine);
      a.breakAuth();
      await engine.syncAll();
      expect(a.draftHeld, isNull);
    });
  });
}
