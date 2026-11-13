import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/notification_payload.dart';
import 'package:postino/core/domain/notification_action.dart';
import 'package:postino/core/domain/notification_target.dart';

void main() {
  test('the payload carries the Conversazione and back, also with separators in the ids', () {
    const target = ConversationTarget((accountId: 'gmail:ada@example.com', conversationId: 't/1,"x"\n'));
    expect(decodePayload(encodePayload(target)), target);
  });

  test('the payload carries the Account of a summary and back', () {
    const target = AccountTarget('gmail:ada@example.com');
    expect(decodePayload(encodePayload(target)), target);
  });

  test('a button of a Conversazione is its Azione on it (#211)', () {
    expect(decodeAction('["a1","t-a"]', 'archive'), (
      conversation: (accountId: 'a1', conversationId: 't-a'),
      action: NotificationAction.archive,
    ));
  });

  test('a button that carries its own payload (Windows: payload and actionId are its arguments)', () {
    final arguments = encodeAction((
      conversation: (accountId: 'a1', conversationId: 't-a'),
      action: NotificationAction.star,
    ));
    expect(decodeAction(arguments, arguments), (
      conversation: (accountId: 'a1', conversationId: 't-a'),
      action: NotificationAction.star,
    ));
    expect(decodePayload(arguments), isNull, reason: 'not a tap on the notification');
    expect(decodeAction('["a1","t-a","snooze"]', null), isNull);
  });

  test('no button, an unknown one or a summary: no Azione', () {
    expect(decodeAction('["a1","t-a"]', null), isNull);
    expect(decodeAction('["a1","t-a"]', ''), isNull);
    expect(decodeAction('["a1","t-a"]', 'snooze'), isNull);
    expect(decodeAction('["a1"]', 'archive'), isNull);
  });

  test('the payload holds the ids only, never text of the mail', () {
    expect(encodePayload(const ConversationTarget((accountId: 'a1', conversationId: 't-a'))), '["a1","t-a"]');
    expect(encodePayload(const AccountTarget('a1')), '["a1"]');
  });

  test('the notification id is the same in every run, per message (#238)', () {
    // FNV-1a computed outside Dart: an Object.hash would differ between processes, so between two starts.
    expect(notificationId('a1', 'm1'), 100827275);
    expect(notificationId('a1', 'm2'), isNot(100827275));
    expect(notificationId('a2', 'm1'), isNot(100827275));
  });

  test("an Account's group summary has its own id, never one of its messages'", () {
    // FNV-1a computed outside Dart, as above: the same group after a restart, and after the update from #210.
    expect(groupId('a1'), 1232372138);
    expect(groupId('a2'), isNot(groupId('a1')));
    final ids = {for (var i = 0; i < 1000; i++) notificationId('a1', 'm$i')};
    expect(ids, hasLength(1000));
    expect(ids, isNot(contains(groupId('a1'))));
    // A message id whose FNV-1a is the group's (found by brute force outside Dart): it moves aside.
    expect(notificationId('a1', 'ff4y4x'), groupId('a1') ^ 1);
  });

  for (final payload in [null, '', 'not json', '{"a":1}', '[]', '[1]', '[1, 2]', '["a", "b", "c"]']) {
    test('a payload Postino did not write ($payload) opens nothing', () {
      expect(decodePayload(payload), isNull);
    });
  }
}
