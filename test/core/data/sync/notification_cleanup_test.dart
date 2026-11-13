// Pulizia delle notifiche (#238): on the seam of the fake Provider, with the real database and sync engine. A
// message's notification goes once it is no longer unread in the inbox, changed elsewhere or here.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/main.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/harness.dart';

void main() {
  late Harness h;
  late FakeMailProvider a;
  late SyncEngine engine;

  Set<String> visible() => h.notifications.visibleConversations;

  setUp(() async {
    h = await Harness.create();
    a = (await h.addAccount('a'))..deliver(msg('0'));
    engine = getIt<SyncEngine>();
    await engine.syncAll();
    a
      ..deliver(msg('1'))
      ..deliver(msg('2'));
    await engine.syncAll();
    expect(visible(), {'t-1', 't-2'});
  });

  test('read elsewhere: at the next sync its notification goes, the other stays', () async {
    a.changeElsewhere('1', readAttribute, true);
    await engine.syncAll();
    expect(visible(), {'t-2'});
  });

  test('archived elsewhere: its notification goes', () async {
    a.changeElsewhere('1', placementAttribute, Placement.archive);
    await engine.syncAll();
    expect(visible(), {'t-2'});
  });

  test('deleted elsewhere (gone from the Provider): its notification goes', () async {
    a.removeRemotely('1');
    await engine.syncAll();
    expect(visible(), {'t-2'});
  });

  test('still unread in the inbox after a change (Stella): its notification stays', () async {
    a.changeElsewhere('1', starredAttribute, true);
    await engine.syncAll();
    expect(visible(), {'t-1', 't-2'});
  });

  test('read here, archived here, or opened here: its notification goes at once', () async {
    await engine.act('a', ['1'], const MarkRead());
    await pumpEventQueue();
    expect(visible(), {'t-2'});

    a.deliver(msg('3'));
    await engine.syncAll();
    await engine.act('a', ['3'], const Archive(), hold: const Duration(seconds: 5));
    await pumpEventQueue();
    expect(visible(), {'t-2'}, reason: 'a held Azione is applied here at once');

    await engine.openConversation('a', 't-2');
    expect(visible(), isEmpty);
  });

  test('two messages of one Conversazione, one read elsewhere: only its notification goes (#238)', () async {
    a
      ..deliver(msg('3', conversationId: 't-3'))
      ..deliver(msg('4', conversationId: 't-3'));
    await engine.syncAll();
    expect(h.notifications.visibleMessages, {'1', '2', '3', '4'});

    a.changeElsewhere('3', readAttribute, true);
    await engine.syncAll();
    expect(h.notifications.visibleMessages, {'1', '2', '4'}, reason: 'the Conversazione is still unread, 4 too');

    await engine.act('a', ['4'], const MarkRead());
    await pumpEventQueue();
    expect(h.notifications.visibleMessages, {'1', '2'});
  });

  test('opened here: the notifications of all its messages go', () async {
    a
      ..deliver(msg('3', conversationId: 't-3'))
      ..deliver(msg('4', conversationId: 't-3'));
    await engine.syncAll();

    await engine.openConversation('a', 't-3');
    expect(h.notifications.visibleMessages, {'1', '2'});
  });
}
