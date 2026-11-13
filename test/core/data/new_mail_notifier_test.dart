import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/notification_payload.dart';
import 'package:postino/core/data/sync/new_mail_notifier.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/notification_action.dart';
import 'package:postino/core/domain/open_conversation.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/fake_notifications.dart';
import '../../support/harness.dart';

const _a1 = Account(id: 'a1', address: 'ada@example.com', provider: ProviderKind.gmail, color: 0, position: 0);
const _a2 = Account(id: 'a2', address: 'bob@example.com', provider: ProviderKind.gmail, color: 0, position: 1);

/// [n] new messages, each in its own Conversazione.
List<Message> _new(int n, {String prefix = 'm'}) => [for (var i = 0; i < n; i++) msg('$prefix$i')];

void main() {
  late FakeNotifications notifications;
  late OpenConversation open;
  late NewMailNotifier notifier;

  setUp(() async {
    await Harness.create();
    notifications = FakeNotifications();
    open = OpenConversation();
    notifier = NewMailNotifier(getIt<MailStore>(), notifications, open, getIt<SettingsRepository>());
  });

  test('a notification carries the buttons of the Azioni delle notifiche: the default, then the chosen ones', () async {
    await notifier.notify(_a1, [msg('m1')]);
    await getIt<SettingsRepository>().setNotificationActions((first: null, second: NotificationAction.delete));
    await notifier.notify(_a1, [msg('m2')]);

    expect(
      [for (final n in notifications.shown) n.actions],
      [
        [NotificationAction.archive, NotificationAction.markRead],
        [NotificationAction.delete],
      ],
    );
  });

  test('three new messages of one Conversazione: three notifications with three ids, oldest first (#238)', () async {
    await notifier.notify(_a1, [
      msg('m2', conversationId: 't', subject: 'Seconda', date: DateTime.utc(2026, 11, 2)),
      msg('m3', conversationId: 't', subject: 'Terza', date: DateTime.utc(2026, 11, 3)),
      msg('m1', conversationId: 't', subject: 'Prima', date: DateTime.utc(2026, 11)),
    ]);

    expect([for (final n in notifications.shown) n.subject], ['Prima', 'Seconda', 'Terza']);
    expect({for (final n in notifications.shown) notificationId('a1', n.messageId)}, hasLength(3));
    expect(notifications.visible['a1'], hasLength(3));
    final (account, ids) = notifications.summarized.single;
    expect(account, 'a1', reason: "the Account's summary once, before the notifications");
    expect(ids, ['m1', 'm2', 'm3']);
  });

  test('on the same date the order does not depend on the batch order', () async {
    final date = DateTime.utc(2026, 11, 4);
    final a = msg('a', conversationId: 't', subject: 'A', date: date);
    final b = msg('b', conversationId: 't', subject: 'B', date: date);
    await notifier.notify(_a1, [b, a]);

    expect([for (final n in notifications.shown) n.subject], ['A', 'B']);
  });

  test('twelve new messages in three Conversazioni: twelve notifications, no threshold (#238)', () async {
    await notifier.notify(_a1, [for (var i = 0; i < 12; i++) msg('m$i', conversationId: 't${i % 3}')]);

    expect(notifications.shown, hasLength(12));
    expect(notifications.visible['a1'], hasLength(12));
    expect(notifications.visibleConversations, {'t0', 't1', 't2'});
    expect({for (final n in notifications.shown) n.accountAddress}, {'ada@example.com'});
  });

  test('two Accounts: two groups', () async {
    await notifier.notify(_a1, _new(2, prefix: 'a'));
    await notifier.notify(_a2, _new(1, prefix: 'b'));

    expect(notifications.visible.keys, unorderedEquals(['a1', 'a2']));
    expect(notifications.visible['a1'], hasLength(2));
    expect(notifications.visible['a2'], hasLength(1));
  });

  test('the messages of the Conversazione on screen do not notify', () async {
    open.show((accountId: 'a1', conversationId: 't'));
    await notifier.notify(_a1, [..._new(10), msg('o1', conversationId: 't'), msg('o2', conversationId: 't')]);

    expect(notifications.shown, hasLength(10));
    expect(notifications.visibleConversations, isNot(contains('t')));
    expect(notifications.summarized.single.$2, isNot(contains('o1')));
  });

  test('nothing to notify: no summary either', () async {
    open.show((accountId: 'a1', conversationId: 't'));
    await notifier.notify(_a1, [msg('o1', conversationId: 't')]);

    expect(notifications.summarized, isEmpty);
  });

  test('a notification the OS refuses does not stop the next ones', () async {
    notifications.failures = 1;
    await notifier.notify(_a1, _new(3));

    expect(notifications.shown, hasLength(2));
  });
}
