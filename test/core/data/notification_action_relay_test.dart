// A button run by a background engine goes to the app's isolate while that one lives (#211).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/notification_action_relay.dart';
import 'package:postino/core/domain/notification_action.dart';

const _tap = (conversation: (accountId: 'a1', conversationId: 't-a'), action: NotificationAction.archive);

void main() {
  test('the app listening: it gets the tap, and the background isolate leaves it alone', () async {
    final got = <NotificationActionTap>[];
    final port = listenForRelayedActions(got.add);
    addTearDown(port.close);

    expect(await relayToApp(_tap), isTrue);
    await pumpEventQueue();
    expect(got, [_tap]);
  });

  test('the app gone, its name left behind: no answer, the background isolate runs it', () async {
    listenForRelayedActions((_) => fail('closed')).close();

    expect(await relayToApp(_tap, wait: const Duration(milliseconds: 50)), isFalse);
  });
}
