// The button of a notification (#211): its Azione on the Conversazione through the offline queue (ADR 0008), the real
// engine over a fake Provider, then the notification goes.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/conflict.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/notification_action.dart';
import 'package:postino/core/domain/notification_action_use_case.dart';
import 'package:postino/core/domain/notification_target.dart';
import 'package:postino/core/domain/outbox_repository.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _t = (accountId: 'a', conversationId: 't');
const _draft = OutgoingMessage(
  messageId: '<bozza@example.com>',
  from: 'a@example.com',
  to: ['b@example.com'],
  subject: 'Bozza',
  body: '<p>Ciao</p>',
);

void main() {
  late Harness h;
  late FakeMailProvider a;
  late NotificationActionUseCase useCase;

  Future<List<Message>> here() async => [
    for (final m in await getIt<InboxRepository>().watchConversation('a', 't').first) m.message,
  ];
  Future<List<IntentRow>> queued() => getIt<PostinoDatabase>().select(getIt<PostinoDatabase>().intents).get();
  Future<List<Conflict>> conflicts() => getIt<InboxRepository>().watchConflicts().first;

  setUp(() async {
    h = await Harness.create();
    a = (await h.addAccount('a'))
      ..deliver(msg('1', conversationId: 't', isRead: true))
      ..deliver(msg('2', conversationId: 't'));
    await getIt<MailSync>().syncAll();
    h.notifications.visible['a'] = {const ConversationTarget(_t)};
    useCase = getIt<NotificationActionUseCase>();
  });

  test('Archivia: the unread messages of its inbox archived here and on the Provider, the notification goes', () async {
    await useCase.run((conversation: _t, action: NotificationAction.archive));

    expect([for (final m in await here()) valueOf(m, placementAttribute)], [Placement.inbox, Placement.archive]);
    expect([for (final c in a.actionCalls) c.$1], ['2'], reason: 'the replay is tried at once');
    expect(await queued(), isEmpty);
    expect(h.notifications.visible['a'], isEmpty);
  });

  test('offline: archived here, the voce waits in the queue', () async {
    a.goOffline();
    await useCase.run((conversation: _t, action: NotificationAction.archive));

    expect([for (final m in await here()) valueOf(m, placementAttribute)], [Placement.inbox, Placement.archive]);
    expect(await queued(), hasLength(1));
  });

  test('Elimina leaves alone the messages of the Conversazione outside the inbox', () async {
    a.deliver(msg('3', conversationId: 't', labelIds: const [sentLabelId]));
    await getIt<MailSync>().syncAll();
    await useCase.run((conversation: _t, action: NotificationAction.delete));

    expect(
      [for (final m in await here()) valueOf(m, placementAttribute)],
      [Placement.inbox, Placement.trash, Placement.archive],
    );
  });

  group('a Bozza left pending by the app (no cross-isolate claim on its upload)', () {
    setUp(() => getIt<OutboxRepository>().saveDraft('a', _draft, updatedAt: 0));

    test('from the background engine only the Azioni go to the Provider: the Bozza stays with the app', () async {
      await useCase.run((conversation: _t, action: NotificationAction.archive), background: true);

      expect([for (final c in a.actionCalls) c.$1], ['2']);
      expect(a.draftCalls, isEmpty);
    });

    test("in the app's isolate the replay takes it along, as every Azione's does", () async {
      await useCase.run((conversation: _t, action: NotificationAction.archive));

      expect(a.draftCalls, hasLength(1));
    });
  });

  test('Da ricollegare: the Azione waits in the queue, no replay', () async {
    await getIt<MailStore>().setStatus('a', AccountStatus.daRicollegare);
    await useCase.run((conversation: _t, action: NotificationAction.markRead));

    expect([for (final m in await here()) m.isRead], [true, true]);
    expect(await queued(), isNotEmpty);
    expect(a.actionCalls, isEmpty);
  });

  test('Stella: the new message is still unread, yet the notification goes', () async {
    await useCase.run((conversation: _t, action: NotificationAction.star));

    expect([for (final m in await here()) m.isStarred], [false, true]);
    expect(h.notifications.visible['a'], isEmpty);
  });

  test('archived elsewhere already: no Conflitto, the value is the wanted one', () async {
    a.changeElsewhere('2', placementAttribute, Placement.archive);
    await useCase.run((conversation: _t, action: NotificationAction.archive));

    expect(await conflicts(), isEmpty);
    expect(await queued(), isEmpty);
    expect(valueOf((await here()).last, placementAttribute), Placement.archive);
  });
}
