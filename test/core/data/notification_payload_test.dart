import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/notification_payload.dart';

void main() {
  test('the payload carries the Conversazione and back, also with separators in the ids', () {
    const key = (accountId: 'gmail:ada@gmail.com', conversationId: 't/1,"x"\n');
    expect(decodePayload(encodePayload(key)), key);
  });

  test('the notification id is the same in every run, per Conversazione', () {
    // FNV-1a computed outside Dart: an Object.hash would differ between processes.
    expect(notificationId((accountId: 'a1', conversationId: 't-a')), 877480721);
    expect(notificationId((accountId: 'a1', conversationId: 't-b')), isNot(877480721));
  });

  for (final payload in [null, '', 'not json', '{"a":1}', '["only one"]', '[1, 2]', '["a", "b", "c"]']) {
    test('a payload Postino did not write ($payload) opens nothing', () {
      expect(decodePayload(payload), isNull);
    });
  }
}
