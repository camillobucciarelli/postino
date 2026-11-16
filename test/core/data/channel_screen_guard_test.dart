// The capture protection of the codice di abbinamento (ADR 0019) over the runners' channel: what goes out, what the
// runner says back, and no runner at all (Linux).
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/channel_screen_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(ChannelScreenGuard.channel, null));

  test('protect sends its bool and answers whether the screen is captured now', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(ChannelScreenGuard.channel, (call) async {
      calls.add(call);
      return call.arguments == true;
    });
    final guard = ChannelScreenGuard();
    expect(await guard.protect(on: true), isTrue);
    expect(await guard.protect(on: false), isFalse);
    expect([for (final c in calls) (c.method, c.arguments)], [('protect', true), ('protect', false)]);
  });

  test('the runner says when the capture starts and stops', () async {
    messenger.setMockMethodCallHandler(ChannelScreenGuard.channel, (_) async => false);
    final guard = ChannelScreenGuard();
    final seen = <bool>[];
    guard.watchCaptured().listen(seen.add);
    await guard.protect(on: true);
    for (final on in [true, false]) {
      await messenger.handlePlatformMessage(
        ChannelScreenGuard.channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall('captured', on)),
        (_) {},
      );
    }
    await pumpEventQueue();
    expect(seen, [true, false]);
  });

  test('no runner (Linux) or a refusal: no protection, and nothing thrown', () async {
    expect(await ChannelScreenGuard().protect(on: true), isFalse);
    messenger.setMockMethodCallHandler(
      ChannelScreenGuard.channel,
      (_) async => throw PlatformException(code: 'failed'),
    );
    expect(await ChannelScreenGuard().protect(on: true), isFalse);
  });
}
