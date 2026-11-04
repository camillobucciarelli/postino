// Invio in background on iOS (#36): a hold over an open (maybe expired) task ends it and begins another.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/platform_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('iOS: hold twice begins, ends the old task, begins again; release ends the new one', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <String>[];
    var next = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemBackgroundSender.channel,
      (call) async {
        calls.add('${call.method} ${call.arguments ?? ''}'.trim());
        return call.method == 'beginBackgroundTask' ? ++next : null;
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemBackgroundSender.channel,
        null,
      ),
    );

    final sender = SystemBackgroundSender();
    await sender.hold('a');
    expect(sender.taskId('a'), 1);
    await sender.hold('a');
    expect(sender.taskId('a'), 2);
    await sender.release('a');
    expect(sender.taskId('a'), isNull);
    expect(calls, ['beginBackgroundTask', 'endBackgroundTask 1', 'beginBackgroundTask', 'endBackgroundTask 2']);
  });
}
