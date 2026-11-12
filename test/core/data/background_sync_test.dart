// Sync in background (#212): the task of WorkManager syncs every attivo Account once, notifies and ends; with the
// app alive it leaves the sync to the app, and the app waits for a task running to end.
import 'dart:async';
import 'dart:io' show SocketException;
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:drift/drift.dart' show TableUpdateQuery;

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/background_sync.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync/sync_owner.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/auto_labels_repository.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void main() {
  late Harness h;
  late FakeMailProvider a;
  late SyncEngine engine;

  setUp(() async {
    h = await Harness.create();
    engine = getIt<SyncEngine>();
    a = (await h.addAccount('a'))..deliver(msg('1'));
    await engine.syncAll();
  });

  test('a new message in the inbox: notified, the cursor saved, and the name free again', () async {
    final before = await getIt<MailStore>().cursor('a');
    a.deliver(msg('2', subject: 'Nuovo'));

    expect(await runSyncTask(), isTrue);

    expect([for (final n in h.notifications.shown) n.subject], ['Nuovo']);
    expect(await getIt<MailStore>().cursor('a'), isNot(before));
    expect(await SyncOwner().tryClaim(), isTrue);
  });

  test('a Da ricollegare Account is skipped', () async {
    await getIt<MailStore>().setStatus('a', AccountStatus.daRicollegare);
    final calls = a.syncCalls;
    a.deliver(msg('2'));

    expect(await runSyncTask(), isTrue);
    expect(a.syncCalls, calls);
    expect(h.notifications.shown, isEmpty);
  });

  test('no Account: nothing', () async {
    await getIt<MailStore>().removeAccount('a', at: h.clock.now());
    final calls = a.syncCalls;
    expect(await runSyncTask(), isTrue);
    expect(a.syncCalls, calls);
  });

  test('a network error, answered or thrown: it ends without throwing and reports success', () async {
    a.goOffline();
    expect(await runSyncTask(), isTrue);

    final failing = a.hold = Completer<void>();
    a.goOnline();
    final task = runSyncTask();
    await pumpEventQueue();
    failing.completeError(const SocketException('rete giù'));
    expect(await task, isTrue);
    expect(h.notifications.shown, isEmpty);
    expect(await SyncOwner().tryClaim(), isTrue);
  });

  test('the app alive: the task does not sync, it asks the app to', () async {
    var asked = 0;
    final app = SyncOwner();
    expect(await app.tryClaim(onAsked: () async => asked++), isTrue);
    addTearDown(app.release);
    final calls = a.syncCalls;
    a.deliver(msg('2'));

    expect(await runSyncTask(), isTrue);
    expect(a.syncCalls, calls);
    expect(asked, 1);
  });

  test('the app started while the task syncs: the app syncs only once the task ended', () async {
    final slow = a.hold = Completer<void>();
    a.deliver(msg('2'));
    final task = runSyncTask();
    await pumpEventQueue();
    final calls = a.syncCalls;

    engine.start();
    addTearDown(engine.stop);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(a.syncCalls, calls);

    a.hold = null;
    slow.complete();
    await task;
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(a.syncCalls, greaterThan(calls));
  });

  test('the app started while the task syncs: its streams read the database again only once the task ended', () async {
    // A table no sync writes: only the refresh after external writes touches it.
    final db = getIt<PostinoDatabase>();
    var refreshes = 0;
    final sub = db.tableUpdates(TableUpdateQuery.onTable(db.trustedSenders)).listen((_) => refreshes++);
    addTearDown(sub.cancel);
    final slow = a.hold = Completer<void>();
    a.deliver(msg('2'));
    final task = runSyncTask();
    await pumpEventQueue();

    engine.start();
    addTearDown(engine.stop);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(refreshes, 0);

    a.hold = null;
    slow.complete();
    await task;
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(refreshes, greaterThan(0));
  });

  test('the app slow but alive (no answer in time): the task keeps off its name and does not sync', () async {
    final slow = RawReceivePort((Object? _) {});
    addTearDown(slow.close);
    IsolateNameServer.registerPortWithName(slow.sendPort, syncOwnerName);
    final calls = a.syncCalls;
    a.deliver(msg('2'));

    expect(await runSyncTask(answerWithin: const Duration(milliseconds: 50)), isTrue);
    expect(a.syncCalls, calls);
    expect(IsolateNameServer.lookupPortByName(syncOwnerName), slow.sendPort);
  });

  test('the app started: the task finds it alive and asks it to sync', () async {
    engine.start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    final calls = a.syncCalls;
    a.deliver(msg('2', subject: 'Nuovo'));

    expect(await runSyncTask(), isTrue);
    await pumpEventQueue();
    expect(a.syncCalls, greaterThan(calls));
    expect([for (final n in h.notifications.shown) n.subject], ['Nuovo']);
  });

  test('the app lost the name (another engine took it over): its next sync claims it back', () async {
    engine.start();
    addTearDown(engine.stop);
    await pumpEventQueue();
    IsolateNameServer.removePortNameMapping(syncOwnerName);

    await engine.syncAll();
    await pumpEventQueue();
    expect(await SyncOwner().tryClaim(), isFalse);
  });

  test('Etichettatura automatica: skipped by the task, done by the next sync in the app', () async {
    const viaggi = 'Label_12';
    final after = h.clock.now().add(const Duration(hours: 1));
    h.embedder.vectorOf = (text) => text.contains('Viaggi') || text.contains('Volo') ? [1, 0] : [0, 1];
    await getIt<AutoLabelsRepository>().setAutomatic('a', viaggi, automatic: true);
    a.deliver(msg('2', subject: 'Volo per Lisbona', date: after));

    await runSyncTask();
    expect(h.embedder.texts, isEmpty);
    expect(a.labelCalls, isEmpty);

    await engine.syncAll();
    await engine.autoLabeling['a'];
    expect(a.labelCalls, [('2', viaggi, true)]);

    // Classified once: the next sync does not take it again.
    h.embedder.texts.clear();
    await engine.syncAll();
    await engine.autoLabeling['a'];
    expect(h.embedder.texts, isEmpty);
  });

  test(
    'Etichettatura automatica: the model not ready at the next sync keeps the deferred mail for the one after',
    () async {
      const viaggi = 'Label_12';
      final after = h.clock.now().add(const Duration(hours: 1));
      List<double> classify(String text) => text.contains('Viaggi') || text.contains('Volo') ? [1, 0] : [0, 1];
      h.embedder.vectorOf = (_) => null;
      await getIt<AutoLabelsRepository>().setAutomatic('a', viaggi, automatic: true);
      a.deliver(msg('2', subject: 'Volo per Lisbona', date: after));
      await runSyncTask();

      await engine.syncAll();
      await engine.autoLabeling['a'];
      expect(a.labelCalls, isEmpty);

      h.embedder.vectorOf = classify;
      await engine.syncAll();
      await engine.autoLabeling['a'];
      expect(a.labelCalls, [('2', viaggi, true)]);
    },
  );
}
