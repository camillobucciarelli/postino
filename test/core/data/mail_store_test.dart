import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';

import '../../support/fake_mail_provider.dart';

Future<MailStore> _store() async {
  final db = PostinoDatabase.inMemory();
  addTearDown(db.close);
  final store = MailStore(db);
  await store.addAccount(
    const Account(id: 'a', address: 'a@example.com', provider: ProviderKind.gmail, color: 0, position: 0),
  );
  return store;
}

void main() {
  test('a sync result for an Account removed meanwhile writes nothing', () async {
    final db = PostinoDatabase.inMemory();
    addTearDown(db.close);
    final store = MailStore(db);
    await store.addAccount(
      const Account(id: 'a', address: 'a@example.com', provider: ProviderKind.gmail, color: 0, position: 0),
    );
    await db.accountsDao.remove('a');

    await store.applySync('a', SyncBatch(cursor: '1', messages: [msg('1')]));
    await store.applyPage('a', [msg('2')], const {});

    for (final t in db.allTables) {
      if (!t.columnsByName.containsKey('account_id')) continue;
      expect(await db.customSelect('SELECT * FROM ${t.actualTableName}').get(), isEmpty, reason: t.actualTableName);
    }
  });

  test('sender name, To, Cc and labels are stored and read back in the Conversazione', () async {
    final store = await _store();
    await store.applySync(
      'a',
      SyncBatch(
        cursor: '1',
        messages: [
          msg(
            '1',
            conversationId: 't',
            fromName: 'Ada Okafor',
            to: const ['Rossi, Carla <c@x.it>', 'me@example.com'],
            cc: const ['Marco Lenti <marco@example.com>'],
            labelIds: const [inboxLabelId, 'IMPORTANT'],
          ),
        ],
      ),
    );
    final m = (await store.watchConversation('a', 't').first).single.message;
    expect((m.from, m.fromName), ('ada@example.com', 'Ada Okafor'));
    expect(m.to, ['Rossi, Carla <c@x.it>', 'me@example.com']);
    expect(m.cc, ['Marco Lenti <marco@example.com>']);
    expect(m.labelIds, unorderedEquals([inboxLabelId, 'IMPORTANT']));
  });

  test('an id both upserted and removed in one batch is kept', () async {
    final store = await _store();
    await store.applySync('a', SyncBatch(cursor: '1', messages: [msg('1')], removedMessageIds: const ['1']));
    final inbox = await store.watchUnifiedInbox().first;
    expect([for (final e in inbox) e.message.id], ['1']);
  });

  test('one row per Conversazione: its latest message, the count, unread if any is', () async {
    final store = await _store();
    DateTime day(int d) => DateTime.utc(2026, 10, d);
    await store.applySync(
      'a',
      SyncBatch(
        cursor: '1',
        messages: [
          msg('1', conversationId: 't', date: day(1)),
          // The reply sits in Inviati only, yet it is the latest of the Conversazione.
          msg('2', conversationId: 't', date: day(3), isRead: true, labelIds: const ['SENT']),
          msg('3', date: day(2), isRead: true),
          // A Conversazione with nothing in the inbox stays out.
          msg('4', date: day(4), labelIds: const ['SENT']),
        ],
      ),
    );
    final rows = await store.watchUnifiedInbox().first;
    expect([for (final e in rows) (e.message.id, e.count, e.unread)], [('2', 2, true), ('3', 1, false)]);
  });

  test('a read made here survives a sync that still says unread', () async {
    final store = await _store();
    await store.applySync('a', SyncBatch(cursor: '1', messages: [msg('1')]));
    await store.markConversationRead('a', 't-1');
    await store.applySync('a', SyncBatch(cursor: '2', messages: [msg('1')]));
    expect((await store.watchUnifiedInbox().first).single.unread, isFalse);
    expect([for (final i in await store.pendingIntents('a')) (i.messageId, i.isRead)], [('1', true)]);

    await store.readDone('a', ['1'], isRead: true);
    expect(await store.pendingIntents('a'), isEmpty);
  });
}
