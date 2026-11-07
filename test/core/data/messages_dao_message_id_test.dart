// The Message-ID an IMAP Azione needs to find a message whose UID is gone (#165).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/mail_provider.dart';

import '../../support/fake_mail_provider.dart';

void main() {
  test('the Message-ID by Provider id and Account; null for a message the Account does not have', () async {
    final db = PostinoDatabase.inMemory();
    addTearDown(db.close);
    await db.messagesDao.applySync('a1', SyncBatch(cursor: '1', messages: [msg('m1')]));
    expect(await db.messagesDao.rfcMessageId('a1', 'm1'), '<m1@example.com>');
    expect(await db.messagesDao.rfcMessageId('a2', 'm1'), isNull);
    expect(await db.messagesDao.rfcMessageId('a1', 'zzz'), isNull);
  });
}
