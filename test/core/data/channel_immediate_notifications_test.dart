// Notifiche immediate (#214): the fixed notification tapped before the app listens (the engine started by the
// service after a reboot, the Activity opened by the tap) still opens the Posta unificata once it does.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/channel_immediate_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> tapFixed() async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      ChannelImmediateNotifications.channel.name,
      const StandardMethodCodec().encodeMethodCall(const MethodCall('openUnified')),
      (_) {},
    );
    await pumpEventQueue();
  }

  test('tapped before anyone listens: given to the first listener, once', () async {
    final service = ChannelImmediateNotifications();
    await tapFixed();
    var opened = 0;
    service.opened.listen((_) => opened++);
    await pumpEventQueue();
    expect(opened, 1);

    await tapFixed();
    expect(opened, 2);
  });

  test('never tapped: nothing for the first listener', () async {
    final service = ChannelImmediateNotifications();
    var opened = 0;
    service.opened.listen((_) => opened++);
    await pumpEventQueue();
    expect(opened, 0);
  });
}
