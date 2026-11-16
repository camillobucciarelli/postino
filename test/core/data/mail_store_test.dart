import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_action.dart';
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
  test(
    'settledMessage: the stored message as the Provider said it, unless an Azione or a Conflitto overlays it (#322)',
    () async {
      final db = PostinoDatabase.inMemory();
      addTearDown(db.close);
      final store = MailStore(db);
      await store.addAccount(
        const Account(id: 'a', address: 'a@example.com', provider: ProviderKind.gmail, color: 0, position: 0),
      );
      await store.applySync(
        'a',
        SyncBatch(
          cursor: '1',
          messages: [
            msg('1', labelIds: ['INBOX', 'UNREAD']),
            msg('2'),
            msg('3'),
          ],
        ),
      );
      expect(await store.settledMessage('a', '1'), msg('1', labelIds: ['INBOX', 'UNREAD']));
      expect(await store.settledMessage('a', 'x'), isNull);
      await store.queue('a', ['2'], const MarkRead());
      expect(await store.settledMessage('a', '2'), isNull, reason: 'queued Azione');
      await store.queue('a', ['3'], const MarkRead());
      await db.intentsDao.conflict('a', '3', 'read', 'true', 'false');
      expect(await db.select(db.intents).get(), hasLength(1), reason: 'only the voce of 2 is left');
      expect(await store.settledMessage('a', '3'), isNull, reason: 'open Conflitto');
    },
  );

  test('settledMessage withBody: null for a message without a stored body (ADR 0003)', () async {
    final store = await _store();
    await store.applySync('a', SyncBatch(cursor: '1', messages: [msg('1')]));
    expect((await store.settledMessage('a', '1'))?.id, '1');
    expect(await store.settledMessage('a', '1', withBody: true), isNull);
    await store.saveBody('a', '1', const MessageBody('Ciao', BodyKind.testo));
    expect((await store.settledMessage('a', '1', withBody: true))?.id, '1');
  });

  test('a sync result for an Account removed meanwhile writes nothing', () async {
    final db = PostinoDatabase.inMemory();
    addTearDown(db.close);
    final store = MailStore(db);
    await store.addAccount(
      const Account(id: 'a', address: 'a@example.com', provider: ProviderKind.gmail, color: 0, position: 0),
    );
    await db.accountsDao.deleteByAccount('a');

    // False: the sync notifies nothing for it.
    expect(await store.applySync('a', SyncBatch(cursor: '1', messages: [msg('1')])), isFalse);
    await store.applyPage('a', [msg('2')], const {});
    await store.saveBody('a', '1', const MessageBody('Ciao', BodyKind.testo));
    await store.saveLabel('a', const Label(id: 'L1', name: 'L1', kind: LabelKind.etichetta));

    for (final t in db.allTables) {
      if (!t.columnsByName.containsKey('account_id')) continue;
      expect(await db.customSelect('SELECT * FROM ${t.actualTableName}').get(), isEmpty, reason: t.actualTableName);
    }
  });

  test('the outbox of a removed Account is empty, not an error', () async {
    final db = PostinoDatabase.inMemory();
    addTearDown(db.close);
    expect(await MailStore(db).watchOutbox('a').first, isEmpty);
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
    final pending = await store.pendingActions('a', DateTime.utc(2026));
    expect([for (final q in pending) (q.messageId, q.action, q.expected)], [('1', const MarkRead(), false)]);

    await store.actionDone('a', pending.single);
    expect(await store.pendingActions('a', DateTime.utc(2026)), isEmpty);
  });
}
