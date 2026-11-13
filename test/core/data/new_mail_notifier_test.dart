import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/sync/new_mail_notifier.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/new_mail_summary.dart';
import 'package:postino/core/domain/notification_action.dart';
import 'package:postino/core/domain/notification_target.dart';
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

  test('several new messages of one Conversazione in a batch out of order: the newest is notified, once', () async {
    await notifier.notify(_a1, [
      msg('m2', conversationId: 't', subject: 'Seconda', date: DateTime.utc(2026, 11, 2)),
      msg('m3', conversationId: 't', subject: 'Terza', date: DateTime.utc(2026, 11, 3)),
      msg('m1', conversationId: 't', subject: 'Prima', date: DateTime.utc(2026, 11)),
      msg('x', conversationId: 'u', subject: 'Altra'),
    ]);

    expect([for (final n in notifications.shown) n.subject], ['Terza', 'Altra']);
  });

  test('on the same date the choice does not depend on the batch order', () async {
    final date = DateTime.utc(2026, 11, 4);
    final a = msg('a', conversationId: 't', subject: 'A', date: date);
    final b = msg('b', conversationId: 't', subject: 'B', date: date);
    await notifier.notify(_a1, [a, b]);
    await notifier.notify(_a1, [b, a]);

    expect([for (final n in notifications.shown) n.subject], ['B', 'B']);
  });

  test("3 new messages in 2 Conversazioni of an Account: 2 notifications in the Account's group", () async {
    await notifier.notify(_a1, [
      msg('m1', conversationId: 't'),
      msg('m2', conversationId: 't'),
      msg('m3', conversationId: 'u'),
    ]);

    expect(notifications.visible.keys, ['a1']);
    expect(notifications.visible['a1'], hasLength(2));
    expect({for (final n in notifications.shown) n.accountAddress}, {'ada@example.com'});
    expect(notifications.summaries, isEmpty);
  });

  test('11 new messages: one summary «11 nuovi messaggi» and no single notification', () async {
    await notifier.notify(_a1, _new(11));

    expect(notifications.shown, isEmpty);
    expect(notifications.summaries, [
      const NewMailSummary(accountId: 'a1', accountAddress: 'ada@example.com', count: 11),
    ]);
    expect(notifications.visible['a1'], {const AccountTarget('a1')});
  });

  test('11 new messages in one Conversazione are 11 messages: the summary', () async {
    await notifier.notify(_a1, [for (var i = 0; i < 11; i++) msg('m$i', conversationId: 't')]);

    expect(notifications.shown, isEmpty);
    expect(notifications.summaries.single.count, 11);
  });

  test('exactly $summaryThreshold new messages: single notifications', () async {
    await notifier.notify(_a1, _new(10));

    expect(notifications.shown, hasLength(10));
    expect(notifications.summaries, isEmpty);
  });

  test("the summary replaces the Account's notifications already shown, not another Account's", () async {
    await notifier.notify(_a1, _new(2, prefix: 'old'));
    await notifier.notify(_a2, _new(1, prefix: 'b'));
    await notifier.notify(_a1, _new(11));

    expect(notifications.visible['a1'], {const AccountTarget('a1')});
    expect(notifications.visible['a2'], hasLength(1));
  });

  test('two Accounts: two groups', () async {
    await notifier.notify(_a1, _new(2, prefix: 'a'));
    await notifier.notify(_a2, _new(1, prefix: 'b'));

    expect(notifications.visible.keys, unorderedEquals(['a1', 'a2']));
    expect(notifications.visible['a1'], hasLength(2));
    expect(notifications.visible['a2'], hasLength(1));
  });

  test('the messages of the Conversazione on screen neither notify nor count toward the summary', () async {
    open.show((accountId: 'a1', conversationId: 't'));
    await notifier.notify(_a1, [..._new(10), msg('o1', conversationId: 't'), msg('o2', conversationId: 't')]);

    expect(notifications.summaries, isEmpty);
    expect(notifications.shown, hasLength(10));
    expect(notifications.visibleConversations, isNot(contains('t')));
  });
}
