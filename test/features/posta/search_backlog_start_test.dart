// The backlog of the search index (#221, ADR 0018) starts with the app's isolate, not with a background one (#306).
// Its own file, so routefly's statics are fresh as in a real launch.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/notification_payload.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/search_index_backlog.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void main() {
  testWidgets('a body stored before the index: a background tap leaves the backlog, the app indexes it', (
    tester,
  ) async {
    final h = await Harness.create();
    (await h.addAccount('a1')).deliver(msg('a', subject: 'Vecchio'));
    final db = getIt<PostinoDatabase>();
    await tester.runAsync(() async {
      await getIt<MailSync>().syncAll();
      // The body as a version without the index stored it: not in the index.
      await db.customStatement(
        "UPDATE bodies SET body = '<p>parolarara</p>', kind = 'html' WHERE account_id = 'a1' AND message_id = 'a'",
      );
      await queueSearchBacklog(db);
    });
    Future<bool> backlog() async => (await tester.runAsync(
      () => db.customSelect("SELECT 1 FROM sqlite_master WHERE name = 'search_index_backlog'").get(),
    ))!.isNotEmpty;
    expect(await backlog(), isTrue);

    await tester.runAsync(
      () => notificationActionDispatcher(
        NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
          payload: encodePayload(const ConversationTarget((accountId: 'a1', conversationId: 't-a'))),
          actionId: 'markRead',
        ),
      ),
    );
    expect(await backlog(), isTrue, reason: 'a background isolate does not start the backlog');

    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(await backlog(), isFalse, reason: 'the app has run the backlog to its end');
    final hits = await tester.runAsync(
      () => db.customSelect("SELECT rowid FROM search_index WHERE search_index MATCH 'parolarara'").get(),
    );
    expect(hits, hasLength(1));
  });
}
