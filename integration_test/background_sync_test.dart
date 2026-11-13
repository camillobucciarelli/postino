// Sync in background (#212, iOS #213). Run on an Android emulator or an iOS simulator.
//
// What this verifies: the WorkManager periodic task is scheduled once and cancelled (the platform round-trip), and
// the task's body, on the real notifications plugin, turns a new message of the fake Provider into a notification
// whose payload opens its Conversazione.
//
// What QA must still verify by hand, since a test cannot kill the app nor wait for the OS: with an Account, close
// Postino (swipe it away), send yourself a message, wait up to ~15 minutes or force the job with
// `adb shell cmd jobscheduler run -f com.cbucciarelli.postino <job id>` (the id from
// `adb shell dumpsys jobscheduler com.cbucciarelli.postino`), and check the notification; tap it: the Conversazione
// opens.
// iOS (#213), same by hand: with Postino in the background (home, not swiped away) pause the app from Xcode or
// `lldb` and run `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"postino.sync"]`
// (the task of WorkManager launches the Dart side in its own engine): the notification appears and opens the
// Conversazione. On a real iPhone the system decides when; only never after a force-quit.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:postino/core/data/background_sync.dart';
import 'package:postino/core/data/local_notifications.dart';
import 'package:postino/core/data/notification_payload.dart';
import 'package:postino/core/data/platform_services.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/core/domain/notifications.dart';
import 'package:postino/main.dart';
import 'package:workmanager/workmanager.dart';

import '../test/support/fake_mail_provider.dart';
import '../test/support/harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  testWidgets('the periodic task: scheduled once, then cancelled', (tester) async {
    await Workmanager().initialize(sendOutboxDispatcher);
    final periodic = SystemPeriodicSync();
    await periodic.schedule();
    await periodic.schedule();
    expect(await Workmanager().isScheduledByUniqueName(SystemPeriodicSync.task), isTrue);
    await periodic.cancel();
    expect(await Workmanager().isScheduledByUniqueName(SystemPeriodicSync.task), isFalse);
  }, skip: !android);

  testWidgets('the task turns a new message into a notification that opens its Conversazione', (tester) async {
    final h = await Harness.create();
    final notifications = LocalNotifications();
    await getIt.unregister<Notifications>();
    getIt.registerSingleton<Notifications>(notifications);
    // As the WorkManager isolate starts them: not the app's, the buttons are not taken here (#211).
    await notifications.start(
      channelName: 'Posta nuova',
      openLabel: 'Apri',
      newMessages: (n) => '$n nuovi messaggi',
      actionLabel: (a) => a.name,
      onAction: null,
    );
    final a = await h.addAccount('a1');
    await getIt<SyncEngine>().syncAll();
    a.deliver(msg('m2', conversationId: 't-2', subject: 'Dal background'));

    expect(await runSyncTask(budget: ios ? iosBudget : null), isTrue);

    final shown = await FlutterLocalNotificationsPlugin().getActiveNotifications();
    expect(
      shown.map((n) => decodePayload(n.payload)),
      contains(const ConversationTarget((accountId: 'a1', conversationId: 't-2'))),
    );
    await notifications.cancel(const [ConversationTarget((accountId: 'a1', conversationId: 't-2'))]);
  }, skip: !android && !ios);
}
