// A mail sync in flight when its Account is removed (#142, ADR 0016): it ends without errors and writes nothing.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void main() {
  test('removing the Account while its sync is in flight leaves no row and throws nothing', () async {
    final h = await Harness.create();
    final provider = (await h.addAccount('a'))
      ..deliver(msg('1'))
      ..deliver(msg('2'));
    final hold = provider.hold = Completer<void>();
    final engine = getIt<SyncEngine>();
    final sync = engine.syncAll();
    await pumpEventQueue();
    // A replay queued behind the sync, checked while the Account still was there.
    final flush = engine.flushDrafts('a');
    await pumpEventQueue();

    final db = getIt<PostinoDatabase>();
    await db.accountsDao.remove('a');
    provider.hold = null;
    hold.complete();
    await (sync, flush).wait;
    await pumpEventQueue();

    for (final t in db.allTables) {
      if (!t.columnsByName.containsKey('account_id')) continue;
      expect(await db.customSelect('SELECT * FROM ${t.actualTableName}').get(), isEmpty, reason: t.actualTableName);
    }
  });
}
