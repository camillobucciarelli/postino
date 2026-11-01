// The Bozze table (#35): local save, the synced mark, and the reconciliation with the Provider's Bozze folder.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';

import '../../support/fake_mail_provider.dart';

OutgoingMessage _draft(String messageId, {String body = '<p>Ciao</p>'}) =>
    OutgoingMessage(
      messageId: messageId,
      from: 'a@example.com',
      to: const ['b@example.com'],
      cc: const ['c@example.com'],
      bcc: const ['d@example.com'],
      subject: 's',
      body: body,
    );

void main() {
  late PostinoDatabase db;
  setUp(() {
    db = PostinoDatabase.inMemory();
    addTearDown(db.close);
  });

  test('save keeps the content and marks the Bozza pending', () async {
    await db.draftsDao.save('a', _draft('<x>'), updatedAt: 10);
    final r = (await db.draftsDao.byId('a', '<x>'))!;
    expect(
      (r.recipients, r.cc, r.bcc, r.subject, r.body, r.updatedAt),
      (
        'b@example.com',
        'c@example.com',
        'd@example.com',
        's',
        '<p>Ciao</p>',
        10,
      ),
    );
    expect((r.pending, r.synced, r.remoteKnown), (true, false, false));
    expect(await db.draftsDao.pending('a'), hasLength(1));
  });

  test(
    'synced clears pending only if the Bozza was not edited meanwhile',
    () async {
      await db.draftsDao.save('a', _draft('<x>'), updatedAt: 10);
      await db.draftsDao.save(
        'a',
        _draft('<x>', body: '<p>2</p>'),
        updatedAt: 20,
      );
      await db.draftsDao.synced('a', '<x>', 10);
      expect((await db.draftsDao.byId('a', '<x>'))!.pending, isTrue);
      await db.draftsDao.synced('a', '<x>', 20);
      final r = (await db.draftsDao.byId('a', '<x>'))!;
      expect((r.pending, r.synced), (false, true));
      // A later edit keeps the synced mark: the next replay is an update, not a creation.
      await db.draftsDao.save(
        'a',
        _draft('<x>', body: '<p>3</p>'),
        updatedAt: 30,
      );
      final again = (await db.draftsDao.byId('a', '<x>'))!;
      expect((again.pending, again.synced), (true, true));
    },
  );

  test(
    'watch lists the Account Bozze newest first; remove drops one',
    () async {
      await db.draftsDao.save('a', _draft('<x>'), updatedAt: 10);
      await db.draftsDao.save('a', _draft('<y>'), updatedAt: 20);
      await db.draftsDao.save('b', _draft('<z>'), updatedAt: 30);
      expect((await db.draftsDao.watch('a').first).map((r) => r.messageId), [
        '<y>',
        '<x>',
      ]);
      await db.draftsDao.remove('a', '<y>');
      expect((await db.draftsDao.watch('a').first).map((r) => r.messageId), [
        '<x>',
      ]);
    },
  );

  group('reconcile', () {
    Future<void> sync(List<Message> messages) => db.messagesDao.applySync(
      'a',
      SyncBatch(cursor: '1', messages: messages),
      fullSnapshot: true,
    );

    test(
      'marks a Bozza remoteKnown once the Provider lists it as DRAFT',
      () async {
        await db.draftsDao.save('a', _draft('<x@example.com>'), updatedAt: 10);
        await sync([
          msg('x', labelIds: const ['DRAFT']),
        ]);
        await db.draftsDao.reconcile('a');
        expect(
          (await db.draftsDao.byId('a', '<x@example.com>'))!.remoteKnown,
          isTrue,
        );
      },
    );

    test('drops a synced, unedited Bozza gone from the Bozze folder', () async {
      await db.draftsDao.save('a', _draft('<x@example.com>'), updatedAt: 10);
      await db.draftsDao.synced('a', '<x@example.com>', 10);
      await sync([
        msg('x', labelIds: const ['DRAFT']),
      ]);
      await db.draftsDao.reconcile('a');
      await sync([]);
      await db.draftsDao.reconcile('a');
      expect(await db.draftsDao.byId('a', '<x@example.com>'), isNull);
    });

    test(
      'keeps a Bozza edited locally, and one the Provider never listed',
      () async {
        await db.draftsDao.save('a', _draft('<x@example.com>'), updatedAt: 10);
        await db.draftsDao.save('a', _draft('<y@example.com>'), updatedAt: 10);
        await db.draftsDao.synced('a', '<y@example.com>', 10);
        await sync([
          msg('x', labelIds: const ['DRAFT']),
        ]);
        await db.draftsDao.reconcile('a');
        await sync([]);
        await db.draftsDao.reconcile('a');
        expect(await db.draftsDao.byId('a', '<x@example.com>'), isNotNull);
        expect(await db.draftsDao.byId('a', '<y@example.com>'), isNotNull);
      },
    );
  });
}
