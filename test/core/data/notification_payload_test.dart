import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/notification_payload.dart';
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

  test('the payload holds the ids only, never text of the mail', () {
    expect(encodePayload(const ConversationTarget((accountId: 'a1', conversationId: 't-a'))), '["a1","t-a"]');
    expect(encodePayload(const AccountTarget('a1')), '["a1"]');
  });

  test('the notification id is the same in every run, per Conversazione', () {
    // FNV-1a computed outside Dart: an Object.hash would differ between processes.
    expect(notificationId((accountId: 'a1', conversationId: 't-a')), 877480721);
    expect(notificationId((accountId: 'a1', conversationId: 't-b')), isNot(877480721));
  });

  test("an Account's summary and group have their own ids, apart from its Conversazioni and from other Accounts", () {
    final ids = {
      summaryId('a1'),
      groupId('a1'),
      summaryId('a2'),
      groupId('a2'),
      notificationId((accountId: 'a1', conversationId: 't-a')),
    };
    expect(ids, hasLength(5));
    // FNV-1a computed outside Dart, as above: the same summary and group after a restart.
    expect(summaryId('a1'), 1559549067);
    expect(groupId('a1'), 1232372138);
  });

  for (final payload in [null, '', 'not json', '{"a":1}', '[]', '[1]', '[1, 2]', '["a", "b", "c"]']) {
    test('a payload Postino did not write ($payload) opens nothing', () {
      expect(decodePayload(payload), isNull);
    });
  }
}
