// A Conversazione opened from a view other than the Cestino or Spam hides its messages in the Cestino or Spam, as
// Gmail does: the reading view, the read marking of the opening and the row of the list agree.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void main() {
  late Harness h;
  late FakeMailProvider a;
  late SyncEngine engine;
  InboxRepository inbox() => getIt<InboxRepository>();

  Future<List<String>> shown(String? view) async => [
    for (final m in await inbox().watchConversation('a', 't-1', view: view).first) m.message.id,
  ];

  // 1 in the inbox, 2 a reply in Inviati only, 3 the newest, unread, deleted.
  setUp(() async {
    h = await Harness.create();
    a = (await h.addAccount('a'))
      ..deliver(msg('1', isRead: true, date: DateTime.utc(2026), snippet: 'primo'))
      ..deliver(
        msg('2', isRead: true, conversationId: 't-1', labelIds: const [sentLabelId], date: DateTime.utc(2026, 2)),
      )
      ..deliver(
        msg('3', conversationId: 't-1', date: DateTime.utc(2026, 3), snippet: 'cestinato', hasAttachments: true),
      );
    engine = getIt<SyncEngine>();
    await engine.syncAll();
    await engine.act('a', ['3'], const Delete());
    await engine.syncAll();
  });

  test('the reading view from the inbox hides the message in the Cestino, not the reply in Inviati', () async {
    expect(await shown(inboxLabelId), ['1', '2']);
    expect(await shown(trashLabelId), ['1', '2', '3'], reason: 'from the Cestino: as before');
    expect(await shown(null), ['1', '2', '3'], reason: 'no view: every message, as before');
  });

  test('opening from the inbox marks only the messages shown as read, here and on the Provider', () async {
    await engine.openConversation('a', 't-1', view: inboxLabelId);
    expect((await inbox().watchMessage('a', '3').first)!.isRead, isFalse);
    final db = getIt<PostinoDatabase>();
    expect(await (db.select(db.intents)..where((t) => t.messageId.equals('3'))).get(), isEmpty);
    expect([
      for (final c in a.actionCalls)
        if (c.$2 is MarkRead) c.$1,
    ], isNot(contains('3')));

    await engine.openConversation('a', 't-1', view: trashLabelId);
    expect((await inbox().watchMessage('a', '3').first)!.isRead, isTrue, reason: 'from the Cestino: as before');
  });

  test('the row in the inbox is made of the messages shown only', () async {
    final row = (await inbox().watchMessages('a', inboxLabelId).first).single;
    expect(row.count, 2);
    expect(row.message.id, '2', reason: 'the latest shown message, not the one in the Cestino');
    expect(row.message.labelIds, isNot(contains(trashLabelId)));
    expect(row.message.hasAttachments, isNot(isTrue));

    final trashed = (await inbox().watchMessages('a', trashLabelId).first).single;
    expect((trashed.count, trashed.message.id), (3, '3'), reason: 'in the Cestino: as before');
  });
}
