// Notifiche immediate (#214). Run on an Android emulator (14 or later for `specialUse`).
//
// What this verifies: the real service starts (the platform round-trip), its fixed notification «Postino in ascolto»
// is shown, a message signalled by the fake Provider becomes a notification within seconds through the engine the
// service keeps alive, and stopping the service takes the fixed notification away.
//
// What QA must verify by hand, since a test cannot close the app from the Recents nor reboot: turn the Notifiche
// immediate on, swipe Postino away from the Recents, check `adb shell dumpsys activity services
// com.cbucciarelli.postino` (ListeningService, `isForeground=true`, types=0x40000000) and that the process lives
// (`adb shell pidof com.cbucciarelli.postino`); send yourself a Gmail and an IMAP message (seconds) and an Outlook.com
// one (~60 s); tap a mail notification: its Conversazione opens on the engine kept alive; tap the fixed notification:
// the Posta unificata opens. `adb reboot`: the fixed notification comes back. Android 14 and 15: after an hour the
// service still runs (`dumpsys`, no timeout).
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:postino/core/data/channel_immediate_notifications.dart';
import 'package:postino/core/data/local_notifications.dart';
import 'package:postino/core/data/notification_payload.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/core/domain/notifications.dart';
import 'package:postino/main.dart';

import '../test/support/fake_mail_provider.dart';
import '../test/support/harness.dart';

/// The id of the fixed notification (ListeningService.kt).
const _listeningId = 214;

Future<List<ActiveNotification>> _active() => FlutterLocalNotificationsPlugin().getActiveNotifications();

/// Waits up to [within] for [test] on the shown notifications.
Future<bool> _shownWithin(Duration within, bool Function(List<ActiveNotification> shown) test) async {
  final end = DateTime.now().add(within);
  while (DateTime.now().isBefore(end)) {
    if (test(await _active())) return true;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  testWidgets('on: the fixed notification shows, a signalled message is notified within seconds; off: it goes', (
    tester,
  ) async {
    final h = await Harness.create();
    final notifications = LocalNotifications();
    await getIt.unregister<Notifications>();
    getIt.registerSingleton<Notifications>(notifications);
    await notifications.start(
      channelName: 'Posta nuova',
      openLabel: 'Apri',
      newMessages: (n) => '$n nuovi messaggi',
      actionLabel: (a) => a.name,
      onAction: null,
    );
    final service = ChannelImmediateNotifications();
    await service.start((
      channel: 'Postino in ascolto',
      title: 'Postino in ascolto',
      text: 'La posta nuova arriva in tempo reale.',
    ));
    expect(await _shownWithin(const Duration(seconds: 5), (s) => s.any((n) => n.id == _listeningId)), isTrue);

    final a = await h.addAccount('a1');
    final engine = getIt<SyncEngine>()..start();
    await engine.syncAll();
    a.deliver(msg('m2', conversationId: 't-2', subject: 'Subito'));
    const target = ConversationTarget((accountId: 'a1', conversationId: 't-2'));
    expect(
      await _shownWithin(const Duration(seconds: 5), (s) => s.any((n) => decodePayload(n.payload) == target)),
      isTrue,
    );

    await service.stop();
    expect(await _shownWithin(const Duration(seconds: 5), (s) => s.every((n) => n.id != _listeningId)), isTrue);
    await engine.stop();
    await notifications.cancel(const [target]);
  }, skip: !android);
}
