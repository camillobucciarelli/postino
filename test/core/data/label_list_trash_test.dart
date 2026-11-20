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
}
