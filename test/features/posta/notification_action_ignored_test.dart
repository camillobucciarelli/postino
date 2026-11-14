// A tap that is not one of ours reaching the background entry point (#211): no payload, or a button we do not know,
// does nothing. Its own file, like notification_action_background_test.dart: routefly's statics stay fresh.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/notification_payload.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void main() {
  testWidgets('no payload, or an unknown button: nothing is done', (tester) async {
    final h = await Harness.create();
    final a = (await h.addAccount('a1'))..deliver(msg('a', subject: 'Da archiviare'));
    await tester.runAsync(() => getIt<MailSync>().syncAll());
    final ours = encodePayload(const ConversationTarget((accountId: 'a1', conversationId: 't-a')));

    for (final (payload, actionId) in [(null, 'archive'), (ours, 'boh')]) {
      await tester.runAsync(
        () => notificationActionDispatcher(
          NotificationResponse(
            notificationResponseType: NotificationResponseType.selectedNotificationAction,
            payload: payload,
            actionId: actionId,
          ),
        ),
      );
    }

    expect(a.actionCalls, isEmpty);
  });
}
