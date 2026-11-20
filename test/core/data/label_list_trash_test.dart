// Elimina from the list of an Etichetta: the Conversazione leaves it, as it leaves the inbox. On the seam of the fake
// Provider (Gmail semantics: a trashed message keeps its other labels), with the real database, queue and list query.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _lavoro = 'Label_7';

void main() {
  late Harness h;
  late FakeMailProvider a;
  late SyncEngine engine;

  Future<List<String>> listed(String labelId) async => [
    for (final e in await getIt<InboxRepository>().watchMessages('a', labelId).first) e.message.id,
  ];

  setUp(() async {
    h = await Harness.create();
    a = (await h.addAccount('a'))..deliver(msg('1', labelIds: const [inboxLabelId, _lavoro]));
    engine = getIt<SyncEngine>();
    await engine.syncAll();
  });

  test('a message deleted from the list of its Etichetta leaves it, here at once and after the sync', () async {
    expect(await listed(_lavoro), ['1']);

    a.goOffline();
    await engine.act('a', ['1'], const Delete());
    expect(await listed(_lavoro), isEmpty, reason: 'the list updates offline');

    a.goOnline();
    await engine.syncAll();
    expect(await listed(_lavoro), isEmpty, reason: 'the Provider keeps the Etichetta on a trashed message');
    expect(await listed(trashLabelId), ['1'], reason: 'the Cestino still lists it');
  });

  test('an unread message in the Cestino or in Spam lights no unread on its Etichetta, only on its own view', () async {
    Future<Set<String>> unread() async => {
      for (final (_, label) in await getIt<InboxRepository>().watchUnreadFolders().first) label,
    };
    expect(await unread(), containsAll([inboxLabelId, _lavoro]));

    await engine.act('a', ['1'], const Delete());
    a.deliver(msg('2', labelIds: const [spamLabelId, _lavoro]));
    await engine.syncAll();
    expect(await unread(), {trashLabelId, spamLabelId});
  });

  test('a message in Spam with an Etichetta is not in the list of the Etichetta', () async {
    a.deliver(msg('2', labelIds: const [spamLabelId, _lavoro]));
    await engine.syncAll();
    expect(await listed(_lavoro), ['1']);
  });

  test('a message deleted from Spam is in the Cestino, not in Spam, before the Provider moves it', () async {
    a.deliver(msg('2', labelIds: const [spamLabelId]));
    await engine.syncAll();
    a.goOffline();
    await engine.act('a', ['2'], const Delete());
    expect(await listed(trashLabelId), ['2']);
    expect(await listed(spamLabelId), isEmpty);
  });

  test('a Conversazione with another message still carrying the Etichetta stays in its list', () async {
    a.deliver(msg('2', labelIds: const [inboxLabelId, _lavoro], conversationId: 't-1'));
    await engine.syncAll();
    await engine.act('a', ['1'], const Delete());
    expect(await listed(_lavoro), hasLength(1), reason: 'one row per Conversazione');
  });

  test('an unread message deleted from a Conversazione still listed makes it unread only in the Cestino', () async {
    await engine.act('a', ['1'], const MarkRead());
    a.deliver(msg('3', conversationId: 't-1'));
    await engine.syncAll();
    await engine.act('a', ['3'], const Delete());
    await engine.syncAll();

    final unread = {for (final (_, label) in await getIt<InboxRepository>().watchUnreadFolders().first) label};
    expect(unread, {trashLabelId});
    Future<bool> rowUnread(String labelId) async =>
        (await getIt<InboxRepository>().watchMessages('a', labelId).first).single.unread;
    expect(await rowUnread(inboxLabelId), isFalse);
    expect(await rowUnread(_lavoro), isFalse);
    expect(await rowUnread(trashLabelId), isTrue);
  });

  test('an unread message in Spam in a Conversazione still listed makes it unread only in Spam', () async {
    await engine.act('a', ['1'], const MarkRead());
    a.deliver(msg('5', conversationId: 't-1', labelIds: const [spamLabelId]));
    await engine.syncAll();

    final unread = {for (final (_, label) in await getIt<InboxRepository>().watchUnreadFolders().first) label};
    expect(unread, {spamLabelId});
    Future<bool> rowUnread(String labelId) async =>
        (await getIt<InboxRepository>().watchMessages('a', labelId).first).single.unread;
    expect(await rowUnread(inboxLabelId), isFalse);
    expect(await rowUnread(_lavoro), isFalse);
    expect(await rowUnread(spamLabelId), isTrue);
  });
}
