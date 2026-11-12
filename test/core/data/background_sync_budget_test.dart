// Sync in background on iOS (#213): the system gives ~30 s, so the task has a budget. Past it no new Account starts
// and the task ends without waiting for the ones syncing; those that finished have their cursor saved, the others not.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/background_sync.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/sync/sync_owner.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void main() {
  late Harness h;
  late FakeMailProvider a;
  late FakeMailProvider b;

  setUp(() async {
    h = await Harness.create();
    a = (await h.addAccount('a'))..deliver(msg('1'));
    b = (await h.addAccount('b'))..deliver(msg('1'));
    await getIt<SyncEngine>().syncAll();
  });

  test('the budget already spent: no Account starts, no cursor moves, no notification', () async {
    final cursors = [await getIt<MailStore>().cursor('a'), await getIt<MailStore>().cursor('b')];
    final calls = [a.syncCalls, b.syncCalls];
    a.deliver(msg('2'));
    b.deliver(msg('2'));

    expect(await runSyncTask(budget: Duration.zero), isTrue);

    expect([a.syncCalls, b.syncCalls], calls);
    expect([await getIt<MailStore>().cursor('a'), await getIt<MailStore>().cursor('b')], cursors);
    expect(h.notifications.shown, isEmpty);
    expect(await SyncOwner().tryClaim(), isTrue);
  });

  test('a budget to spare: every Account syncs, as without one', () async {
    a.deliver(msg('2', subject: 'Per A'));
    b.deliver(msg('2', subject: 'Per B'));

    expect(await runSyncTask(budget: iosBudget), isTrue);

    expect({for (final n in h.notifications.shown) n.subject}, {'Per A', 'Per B'});
  });

  test('an Account still syncing when the budget ends: the task ends, the one that finished has its cursor', () async {
    final before = await getIt<MailStore>().cursor('a');
    final beforeB = await getIt<MailStore>().cursor('b');
    final slow = a.hold = Completer<void>();
    a.deliver(msg('2'));
    b.deliver(msg('2', subject: 'Per B'));

    expect(await runSyncTask(budget: const Duration(milliseconds: 200)), isTrue);

    expect(await getIt<MailStore>().cursor('a'), before);
    expect(await getIt<MailStore>().cursor('b'), isNot(beforeB));
    expect([for (final n in h.notifications.shown) n.subject], ['Per B']);
    // The next run picks A up again.
    a.hold = null;
    slow.complete();
    expect(await runSyncTask(), isTrue);
    expect(await getIt<MailStore>().cursor('a'), isNot(before));
  });

  test('on iOS the task skips the Etichettatura automatica, as on Android', () async {
    a.deliver(msg('2'));
    h.embedder.texts.clear();

    expect(await runSyncTask(budget: iosBudget), isTrue);

    expect(h.embedder.texts, isEmpty);
    expect(getIt<SyncEngine>().autoLabeling, isEmpty);
  });
}
