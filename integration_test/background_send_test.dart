// Invio in background (#36). Run on an iOS simulator and an Android emulator.
//
// What this verifies: the platform hooks round-trip (iOS: hold begins a background task, a second hold replaces it,
// release ends it; Android: the WorkManager one-shot is scheduled by hold and cancelled by release, and the task's
// body sends a row queued in the real database), and a message still queued in the real database goes with a fresh
// engine start, which is the path after the app was killed.
//
// What QA must still verify by hand, since a test cannot background or kill the app: Invia, leave the app within
// 10 s (home or app switcher), wait, and check that the message arrives (iOS: the task runs ~30 s after
// backgrounding; Android: WorkManager runs the dispatcher once the network is up, usually within a minute).
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:postino/core/data/background_send.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/mime.dart';
import 'package:postino/core/data/platform_services.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/main.dart' show sendOutboxDispatcher;
import 'package:workmanager/workmanager.dart';

import '../test/support/fake_mail_provider.dart';
import '../test/support/fake_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final mobile = switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    _ => false,
  };

  testWidgets('iOS: hold begins a background task, release ends it', (
    tester,
  ) async {
    final sender = SystemBackgroundSender();
    await sender.hold('a');
    final first = sender.taskId('a');
    expect(first, isNotNull); // 0 (UIBackgroundTaskInvalid) is never kept
    // A second hold (the first may have expired) ends it and begins another.
    await sender.hold('a');
    expect(sender.taskId('a'), allOf(isNotNull, isNot(first)));
    await sender.release('a');
    expect(sender.taskId('a'), isNull);
  }, skip: defaultTargetPlatform != TargetPlatform.iOS);

  testWidgets(
    'Android: hold schedules the WorkManager task, release cancels it',
    (tester) async {
      await Workmanager().initialize(sendOutboxDispatcher);
      final sender = SystemBackgroundSender();
      final name = SystemBackgroundSender.workName('a');
      await sender.hold('a');
      expect(await Workmanager().isScheduledByUniqueName(name), isTrue);
      await sender.release('a');
      expect(await Workmanager().isScheduledByUniqueName(name), isFalse);
    },
    skip: defaultTargetPlatform != TargetPlatform.android,
  );

  testWidgets(
    'Android: the WorkManager task sends a due row of the real database',
    (tester) async {
      final (store, provider) = await _realStore('it_outbox_task.db');
      final clock = FakeClock(DateTime.now().toUtc());
      GetIt.I.registerSingleton<SyncEngine>(
        SyncEngine(store, clock, FakeConnectivity(), FakeBackgroundSender()),
      );
      await store.enqueueOutgoing(
        'a',
        _message,
        raw: renderMime(_message, clock.now()),
        sendAfter: clock.now().millisecondsSinceEpoch,
      );
      expect(await runOutboxTask('a'), isTrue);
      expect(provider.sent, hasLength(1));
      expect(await store.hasOutgoing('a'), isFalse);
    },
    skip: defaultTargetPlatform != TargetPlatform.android,
  );

  testWidgets('a message queued in the real database goes at the next start', (
    tester,
  ) async {
    final (store, provider) = await _realStore('it_outbox.db');
    const message = _message;

    // Invia, then the app dies before the window ends: the row stays.
    final clock = FakeClock(DateTime.now().toUtc());
    final first = SyncEngine(
      store,
      clock,
      FakeConnectivity(),
      FakeBackgroundSender(),
    );
    await first.send('a', message);
    await first.stop();
    expect(provider.sent, isEmpty);

    // The next start sends what is due.
    clock.advance(const Duration(minutes: 1));
    final restarted = SyncEngine(
      store,
      clock,
      FakeConnectivity(),
      FakeBackgroundSender(),
    );
    restarted.start();
    addTearDown(restarted.stop);
    await tester.pumpAndSettle();
    expect(provider.sent, hasLength(1));
    expect(await store.hasOutgoing('a'), isFalse);
  }, skip: !mobile);
}

const _message = OutgoingMessage(
  messageId: '<x@example.com>',
  from: 'a@example.com',
  to: ['b@example.com'],
  subject: 's',
  body: '<p>Ciao</p>',
);

/// A fresh SQLCipher database file with Account `a`, whose fake Provider is registered by its id.
Future<(MailStore, FakeMailProvider)> _realStore(String name) async {
  final path = '${(await getTemporaryDirectory()).path}/$name';
  for (final f in [File(path), File('$path-journal')]) {
    if (f.existsSync()) f.deleteSync();
  }
  final db = await PostinoDatabase.open(path, KeychainStore());
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
  final provider = FakeMailProvider();
  await GetIt.I.reset();
  GetIt.I.registerSingleton<MailProvider>(provider, instanceName: 'a');
  return (store, provider);
}
