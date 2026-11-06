import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/outbox_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/message.dart';

const _msg = OutgoingMessage(
  messageId: 'm1',
  from: 'a@example.com',
  to: ['b@example.com'],
  subject: 'Hi',
  body: '<p>x</p>',
);

Future<OutboxStore> _store() async {
  final db = PostinoDatabase.inMemory();
  addTearDown(db.close);
  await MailStore(
    db,
  ).addAccount(const Account(id: 'a', address: 'a@example.com', provider: ProviderKind.gmail, color: 0, position: 0));
  return OutboxStore(db);
}

void main() {
  test('a Bozza adopted after its Account was removed is not kept', () async {
    final db = PostinoDatabase.inMemory();
    addTearDown(db.close);
    await MailStore(
      db,
    ).addAccount(const Account(id: 'a', address: 'a@example.com', provider: ProviderKind.gmail, color: 0, position: 0));
    await db.accountsDao.remove('a');

    expect(await OutboxStore(db).adoptDraft('a', _msg, updatedAt: 5), isFalse);
    expect(await db.select(db.drafts).get(), isEmpty);
  });

  test('an enqueued message is read back and counts as outgoing', () async {
    final s = await _store();
    expect(await s.hasOutgoing('a'), isFalse);
    await s.enqueueOutgoing('a', _msg, version: 1, raw: 'RAW', sendAfter: 10);
    expect(await s.hasOutgoing('a'), isTrue);
    expect((await s.outgoing('a', 'm1'))!.raw, 'RAW');
  });

  test('a local Bozza is saved and read back with the Account address', () async {
    final s = await _store();
    await s.saveDraft('a', _msg, updatedAt: 5);
    final d = (await s.localDraft('a', 'm1'))!;
    expect(d.draft.from, 'a@example.com');
    expect(d.draft.subject, 'Hi');
    expect(d.pending, isTrue);
  });

  test('a removed Bozza is gone', () async {
    final s = await _store();
    await s.saveDraft('a', _msg, updatedAt: 5);
    await s.removeDraft('a', 'm1');
    expect(await s.localDraft('a', 'm1'), isNull);
  });
}
