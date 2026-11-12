// A notification's button in a background engine (#211) and the owner of the sync (#212): the real engine over a
// fake Provider.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/background_notification_action.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync/sync_owner.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/notification_action.dart';
import 'package:postino/core/domain/outbox_repository.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _tap = (conversation: (accountId: 'a', conversationId: 't'), action: NotificationAction.archive);
const _draft = OutgoingMessage(
  messageId: '<bozza@example.com>',
  from: 'a@example.com',
  to: ['b@example.com'],
  subject: 'Bozza',
  body: '<p>Ciao</p>',
);

void main() {
  late FakeMailProvider a;

  Future<Object> placement() async =>
      valueOf((await getIt<InboxRepository>().watchConversation('a', 't').first).single.message, placementAttribute);
  Future<List<IntentRow>> queued() => getIt<PostinoDatabase>().select(getIt<PostinoDatabase>().intents).get();

  setUp(() async {
    final h = await Harness.create();
    a = (await h.addAccount('a'))..deliver(msg('1', conversationId: 't'));
    await getIt<MailSync>().syncAll();
    // Left pending by the app: its upload has no claim across isolates.
    await getIt<OutboxRepository>().saveDraft('a', _draft, updatedAt: 0);
  });

  test('nobody owns the sync: it owns it, sends the Azione alone, then gives the name back', () async {
    await runNotificationActionTask(_tap);

    expect(await placement(), Placement.archive);
    expect([for (final c in a.actionCalls) c.$1], ['1']);
    expect(await queued(), isEmpty);
    expect(a.draftCalls, isEmpty, reason: 'the Bozza stays with the app');
    final next = SyncOwner();
    expect(await next.tryClaim(), isTrue, reason: 'released');
    next.release();
  });

  test(
    'a background sync owns it: the Azione is applied here and waits queued, nothing sent next to that sync',
    () async {
      final worker = SyncOwner();
      expect(await worker.tryClaim(), isTrue);
      addTearDown(worker.release);

      await runNotificationActionTask(_tap, answerWithin: const Duration(seconds: 1));

      expect(await placement(), Placement.archive);
      expect(await queued(), hasLength(1));
      expect(a.actionCalls, isEmpty);

      // That sync's batch, fetched before the Azione, lands now: the queued voce keeps it from undoing the Azione.
      await getIt<MailStore>().applyPage('a', [msg('1', conversationId: 't')], const {});
      expect(await placement(), Placement.archive);
    },
  );
}
