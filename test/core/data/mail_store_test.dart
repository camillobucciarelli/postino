import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';

import '../../support/fake_mail_provider.dart';

void main() {
  test('an id both upserted and removed in one batch is kept', () async {
    final db = PostinoDatabase.inMemory();
    addTearDown(db.close);
    final store = MailStore(db);
    await store.addAccount(
      const Account(
        id: 'a',
        address: 'a@example.com',
        provider: ProviderKind.gmail,
        color: 0,
        position: 0,
      ),
    );
    await store.applySync(
      'a',
      SyncBatch(cursor: '1', messages: [msg('1')], removedMessageIds: ['1']),
    );
    final inbox = await store.watchUnifiedInbox().first;
    expect([for (final e in inbox) e.message.id], ['1']);
  });
}
