// The IMAP adapter on GreenMail beyond the contract: incremental sync cases, UIDVALIDITY reset, folders,
// Message-ID lookup, Conversazioni across syncs, IDLE with a password.
@Tags(['imap'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../../support/fake_mail_provider.dart' show msg;
import '../../../support/gmail_recorded.dart' show isErr, okValue;
import '../../../support/greenmail_server.dart';
import '../../../support/imap_harness.dart';

void main() {
  if (imapSkipReason case final reason?) {
    test('IMAP adapter', () {}, skip: reason);
    return;
  }
  late ImapHarness h;
  setUp(() async => h = await ImapHarness.create());
  tearDown(() => h.dispose());
  tearDownAll(ImapHarness.stopServer);

  group('incremental sync', () {
    test('new, read, starred, moved to another folder, deleted', () async {
      await h.deliver(msg('a'));
      await h.deliver(msg('b'));
      await h.deliver(msg('c'));
      final first = okValue(await h.provider.initialSync());
      final movedFrom = h.idOf('b');
      await h.deliver(msg('a', isRead: true));
      await h.deliver(msg('b', labelIds: const ['Viaggi'], isStarred: true));
      await h.removeRemotely('c');
      await h.deliver(msg('d'));
      final next = okValue(await h.provider.incrementalSync(first.cursor));
      final byId = {for (final m in next.messages) m.id: m};
      expect(byId.keys, unorderedEquals([h.idOf('a'), h.idOf('b'), h.idOf('d')]));
      expect(byId[h.idOf('a')]!.isRead, isTrue);
      // Read elsewhere, it keeps its preview.
      expect(byId[h.idOf('a')]!.snippet, 'Ciao');
      expect(h.idOf('b'), startsWith('Viaggi/'));
      expect(byId[h.idOf('b')]!.labelIds, ['Viaggi', starredLabelId]);
      expect(
        next.removedMessageIds,
        unorderedEquals([movedFrom, first.messages.singleWhere((m) => m.messageId == '<c@example.com>').id]),
      );
      expect(next.bodies.keys, unorderedEquals([h.idOf('a'), h.idOf('d')]));
    });

    test('no change: the same cursor, still valid', () async {
      await h.deliver(msg('a'));
      final first = okValue(await h.provider.initialSync());
      final next = okValue(await h.provider.incrementalSync(first.cursor));
      expect(next.messages, isEmpty);
      expect(next.removedMessageIds, isEmpty);
      expect(next.cursor, first.cursor);
      expect(okValue(await h.provider.incrementalSync(next.cursor)).messages, isEmpty);
    });

    test('a new UIDVALIDITY rebuilds the folder, without duplicates in the local database', () async {
      final db = PostinoDatabase.inMemory();
      addTearDown(db.close);
      final store = MailStore(db);
      await store.addAccount(
        Account(id: h.accountId, address: h.address, provider: ProviderKind.imap, color: 0, position: 0),
      );
      await h.deliver(msg('a'));
      await h.deliver(msg('b'));
      final first = okValue(await h.provider.initialSync());
      await store.applySync(h.accountId, first, fullSnapshot: true);
      // GreenMail's UIDVALIDITY is in seconds.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await h.expireCursors();
      await h.withClient((c) async {}); // the new mailbox exists
      await h.deliver(msg('a'));
      await h.deliver(msg('b'));
      expect(h.idOf('a'), isNot(first.messages.singleWhere((m) => m.messageId == '<a@example.com>').id));
      final next = okValue(await h.provider.incrementalSync(first.cursor));
      expect(next.removedMessageIds, unorderedEquals(first.messages.map((m) => m.id)));
      await store.applySync(h.accountId, next);
      final stored = await db.select(db.messages).get();
      expect(stored.map((m) => m.id), unorderedEquals([h.idOf('a'), h.idOf('b')]));
    });

    test('an unreadable cursor is NotFound', () async {
      expect(await h.provider.incrementalSync('{"v":1}'), isErr<NotFoundFailure>());
    });
  });

  test('folders are cartelle: Sent by its name, nested ones by their full path', () async {
    await h.provider.createLabel('Viaggi/2026');
    await h.deliver(msg('s', labelIds: const [sentLabelId]));
    await h.deliver(msg('v', labelIds: const ['Viaggi/2026']));
    final batch = okValue(await h.provider.initialSync());
    expect(
      batch.labels,
      unorderedEquals([
        const Label(id: 'Viaggi', name: 'Viaggi', kind: LabelKind.cartella),
        const Label(id: 'Viaggi/2026', name: 'Viaggi/2026', kind: LabelKind.cartella),
      ]),
    );
    final byKey = {for (final m in batch.messages) m.messageId: m.labelIds};
    expect(byKey['<s@example.com>'], [sentLabelId]);
    expect(byKey['<v@example.com>'], ['Viaggi/2026']);
  });

  test('a message is found by its Message-ID in any synced folder', () async {
    await h.deliver(msg('v', labelIds: const ['Viaggi']));
    expect(okValue(await h.provider.findByMessageId('<v@example.com>')), h.idOf('v'));
    expect(okValue(await h.provider.findByMessageId('<nope@example.com>')), isNull);
  });

  test('a reply arriving later joins the Conversazione it answers, by In-Reply-To or by subject', () async {
    await h.deliver(msg('a', subject: 'Pranzo', from: 'bob@example.com', to: [h.address]));
    await h.deliver(msg('p', subject: 'Preventivo', references: const ['<root@example.com>']));
    final first = okValue(await h.provider.initialSync());
    // Only In-Reply-To: its parent, in the previous sync, is looked up on the server.
    await h.append(
      'INBOX',
      'From: carla@example.com\r\nTo: ${h.address}\r\nSubject: Re: Preventivo\r\n'
          'Date: Fri, 02 Jan 2026 10:00:00 +0000\r\nMessage-ID: <r@example.com>\r\n'
          'In-Reply-To: <p@example.com>\r\n\r\nOk\r\n',
    );
    await h.deliver(
      msg('b', subject: 'Re: Pranzo', from: 'bob@example.com', to: [h.address], date: DateTime.utc(2026, 1, 2)),
    );
    await h.deliver(
      msg('c', subject: 'Pranzo', from: 'carla@example.com', to: [h.address], date: DateTime.utc(2026, 1, 3)),
    );
    final next = okValue(await h.provider.incrementalSync(first.cursor));
    final byKey = {for (final m in next.messages) m.messageId: m.conversationId};
    expect(byKey['<r@example.com>'], '<root@example.com>');
    expect(byKey['<b@example.com>'], '<a@example.com>');
    expect(byKey['<c@example.com>'], '<c@example.com>');
  });

  test('a reply whose subject has no ASCII fragment still joins its Conversazione', () async {
    await h.deliver(msg('a', subject: '会议', from: 'bob@example.com', to: [h.address]));
    final first = okValue(await h.provider.initialSync());
    await h.deliver(
      msg('b', subject: 'Re: 会议', from: 'bob@example.com', to: [h.address], date: DateTime.utc(2026, 1, 2)),
    );
    final next = okValue(await h.provider.incrementalSync(first.cursor));
    expect(next.messages.single.conversationId, '<a@example.com>');
  });

  test('a Conversazione keeps its id when a message of a long In-Reply-To chain comes back changed', () async {
    String raw(String id, String header) =>
        'From: bob@example.com\r\nTo: ${h.address}\r\nSubject: Re: Gita\r\n'
        'Date: Fri, 02 Jan 2026 10:00:00 +0000\r\nMessage-ID: <$id@example.com>\r\n$header\r\n\r\nOk\r\n';
    // m0 with References, then m1..m7 each answering the one before with only In-Reply-To.
    await h.append('INBOX', raw('m0', 'References: <root@example.com>'));
    for (var i = 1; i < 8; i++) {
      await h.append('INBOX', raw('m$i', 'In-Reply-To: <m${i - 1}@example.com>'));
    }
    final first = okValue(await h.provider.initialSync());
    expect(first.messages.map((m) => m.conversationId).toSet(), {'<root@example.com>'});
    // Only the last one changes: its whole chain is looked up again, back to the same root.
    await h.deliver(msg('m7', isRead: true));
    final next = okValue(await h.provider.incrementalSync(first.cursor));
    expect(next.messages.single.conversationId, '<root@example.com>');
  });

  test('IDLE with a password: up, then changed when a message arrives', () async {
    final queue = StreamIterator(h.provider.changes);
    addTearDown(queue.cancel);
    expect(await queue.moveNext(), isTrue);
    expect(queue.current, ChangeSignal.up);
    await h.deliver(msg('a'));
    expect(await queue.moveNext().timeout(const Duration(seconds: 10)), isTrue);
    expect(queue.current, ChangeSignal.changed);
  });
}
