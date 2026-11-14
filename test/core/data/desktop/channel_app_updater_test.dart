// macOS (#122): «Cerca aggiornamenti» asks Sparkle through the runner, which answers in its own window; no Banner.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/desktop/channel_app_updater.dart';
import 'package:postino/core/domain/app_updater.dart';
import 'package:postino/core/domain/result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('asks the runner and says Sparkle showed its window; nothing for the Banner', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      ChannelAppUpdater.channel,
      (call) async => calls.add(call.method),
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        ChannelAppUpdater.channel,
        null,
      ),
    );
    const u = ChannelAppUpdater();
    expect(await u.checkForUpdates(), isA<Ok<UpdateCheck>>().having((r) => r.value, 'value', UpdateCheck.shown));
    expect(calls, ['checkForUpdates']);
    expect(u.supported, isTrue);
    expect(u.available, isNull);
  });
}
