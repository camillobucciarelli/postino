// Notifiche con deep link ad avvio a freddo (#39). Run on an iOS simulator and an Android emulator.
//
// What this verifies: the real plugin starts (a run not launched by a notification has no Conversazione to open)
// and its show and permission check do not throw (a smoke check: whether the banner appears is QA's); the app
// started with the Conversazione of a cold launch opens it over the Posta unificata, with real frames and the real
// router, Indietro coming back to it.
//
// What QA must still verify by hand, since a test cannot kill the app and tap the notification: with notifications
// allowed, receive a new message (the app open), close the app (swipe it away), tap the notification: the
// Conversazione opens, and Indietro shows the Posta unificata. Prior art: prototype/deep-link-cold-start (#8).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:postino/core/data/local_notifications.dart';
import 'package:postino/core/domain/mail_notification.dart';
import 'package:postino/core/domain/notification_action.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../test/support/fake_mail_provider.dart';
import '../test/support/harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final mobile = !kIsWeb && {TargetPlatform.iOS, TargetPlatform.android}.contains(defaultTargetPlatform);

  testWidgets('the cold launch opens its Conversazione over the Posta unificata; Indietro comes back', (tester) async {
    final h = await Harness.create();
    (await h.addAccount('a1')).deliver(msg('a', subject: 'Dalla notifica'));
    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(
      TranslationProvider(
        child: const PostinoApp(launch: ConversationTarget((accountId: 'a1', conversationId: 't-a'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<ConversationView>(find.byType(ConversationView)).conversationId, 't-a');

    await tester.tap(find.byWidgetPredicate((w) => w is PostinoIcon && w.icon == PostinoIcons.arrowLeft));
    await tester.pumpAndSettle();
    expect(Routefly.currentUri.path, routePaths.posta.path);
    expect(find.byType(ConversationView), findsNothing);
  }, skip: !mobile);

  testWidgets('smoke: the real plugin starts with no launch; show, cancel and the permission check do not throw', (
    tester,
  ) async {
    final notifications = LocalNotifications();
    expect(
      await notifications.start(
        channelName: 'Posta nuova',
        openLabel: 'Apri',
        newMessages: (n) => '$n nuovi messaggi',
        actionLabel: (a) => a.name,
        onAction: (_) {},
      ),
      isNull,
    );
    // #238: two messages of a Conversazione, two notifications (and the group summary on Android).
    for (final id in ['m1', 'm2']) {
      await notifications.show(
        MailNotification(
          conversation: (accountId: 'a1', conversationId: 't-a'),
          messageId: id,
          accountAddress: 'a1@example.com',
          sender: 'Ada',
          subject: 'Prova',
          preview: 'Notifica di prova',
          // #211: with its buttons (a category on iOS).
          actions: const [NotificationAction.archive, NotificationAction.markRead],
        ),
      );
    }
    // The cleanup removes them, and the summary with the last.
    await notifications.cancel('a1', ['m1', 'm2']);
    await notifications.permissionNeeded();
  }, skip: !mobile);
}
