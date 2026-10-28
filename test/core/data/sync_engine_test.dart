import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void main() {
  late Harness h;
  late FakeMailProvider a, b;

  Future<List<String>> inbox() async => [
    for (final e in await getIt<InboxRepository>().watchUnifiedInbox().first)
      '${e.account.id}:${e.message.id}',
  ]..sort();

  setUp(() async {
    h = await Harness.create();
    a = (await h.addAccount('a'))
      ..deliver(msg('1'))
      ..deliver(msg('2'));
    b = (await h.addAccount('b'))..deliver(msg('1'));
    await GetIt.I<SyncEngine>().syncAll();
  });

  test('a message removed on the Provider disappears after re-sync', () async {
    expect(await inbox(), ['a:1', 'a:2', 'b:1']);
    a.removeRemotely('2');
    await GetIt.I<SyncEngine>().syncAll();
    expect(await inbox(), ['a:1', 'b:1']);
  });

  test('a failed sync deletes nothing', () async {
    a.removeRemotely('2');
    a.goOffline();
    await GetIt.I<SyncEngine>().syncAll();
    expect(await inbox(), ['a:1', 'a:2', 'b:1']);
  });

  test('other Accounts are untouched', () async {
    b.removeRemotely('1');
    a.goOffline();
    await GetIt.I<SyncEngine>().syncAll();
    expect(await inbox(), ['a:1', 'a:2']);
  });

  test(
    'an empty initial snapshot clears the Account cache, labels included',
    () async {
      a.removeRemotely('1');
      a.removeRemotely('2');
      await GetIt.I<SyncEngine>().syncAll();
      expect(await inbox(), ['b:1']);
      final db = GetIt.I<PostinoDatabase>();
      for (final table in ['messages', 'message_labels']) {
        expect(
          await db
              .customSelect("SELECT 1 FROM $table WHERE account_id = 'a'")
              .get(),
          isEmpty,
        );
      }
    },
  );

  test(
    'a snapshot larger than the SQL variable limit still reconciles',
    () async {
      for (var i = 0; i < 40000; i++) {
        a.deliver(msg('big$i'));
      }
      await GetIt.I<SyncEngine>().syncAll();
      a.removeRemotely('1');
      await GetIt.I<SyncEngine>().syncAll();
      expect(
        (await inbox()).length,
        40000 + 1 + 1,
      ); // a: 2 + big - '1', plus b:1
    },
  );
}
