import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
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
    a = h.addAccount('a')
      ..deliver(msg('1'))
      ..deliver(msg('2'));
    b = h.addAccount('b')..deliver(msg('1'));
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
}
