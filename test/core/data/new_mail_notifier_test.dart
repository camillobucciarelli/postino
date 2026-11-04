import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/sync/new_mail_notifier.dart';
import 'package:postino/core/domain/open_conversation.dart';
import 'package:postino/main.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/fake_notifications.dart';
import '../../support/harness.dart';

void main() {
  late FakeNotifications notifications;
  late NewMailNotifier notifier;

  setUp(() async {
    await Harness.create();
    notifications = FakeNotifications();
    notifier = NewMailNotifier(getIt<MailStore>(), notifications, OpenConversation());
  });

  test('several new messages of one Conversazione in a batch out of order: the newest is notified, once', () async {
    await notifier.notify('a1', [
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
    await notifier.notify('a1', [a, b]);
    await notifier.notify('a1', [b, a]);

    expect([for (final n in notifications.shown) n.subject], ['B', 'B']);
  });
}
