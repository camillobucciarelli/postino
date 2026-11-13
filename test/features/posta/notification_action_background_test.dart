// «Archivia» from a notification with the app not running (#211): the background engine's entry point runs the Azione
// through the offline queue; at the next start the Conversazione is archived and the queue empty. Its own file, so
// routefly's statics are fresh as in a real launch.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/notification_payload.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void main() {
  testWidgets('Archivia in the background, then the app starts: archived, the queue empty', (tester) async {
    final h = await Harness.create();
    final a = (await h.addAccount('a1'))..deliver(msg('a', subject: 'Da archiviare'));
    await tester.runAsync(() => getIt<MailSync>().syncAll());

    await tester.runAsync(
      () => notificationActionDispatcher(
        NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
          payload: encodePayload(const ConversationTarget((accountId: 'a1', conversationId: 't-a'))),
          actionId: 'archive',
        ),
      ),
    );

    final db = getIt<PostinoDatabase>();
    expect(await tester.runAsync(() => db.select(db.intents).get()), isEmpty);
    expect(a.actionCalls.map((c) => (c.$1, c.$2)), [('a', const Archive())]);

    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    await tester.pumpAndSettle();
    expect(find.text('Da archiviare'), findsNothing);
  });
}
