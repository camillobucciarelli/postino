import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../domain/immediate_notifications.dart';

/// Android's Notifiche immediate (#214): `ListeningService`, the `specialUse` foreground service that keeps the app's
/// engine, and with it this isolate's SyncEngine (IDLE, the 60 s poll), alive with Postino closed. Nothing elsewhere.
@LazySingleton(as: ImmediateNotifications, env: [Environment.prod])
class ChannelImmediateNotifications() implements ImmediateNotifications {
  /// The runner's channel (`PostinoEngine.kt`): `start({channel, title, text})`, `stop`, `requestBatteryExemption`
  /// → bool; from the runner `openUnified`.
  static const channel = MethodChannel('it.postino/immediate_notifications');

  late final StreamController<void> _opened = StreamController<void>.broadcast(
    onListen: () => channel.setMethodCallHandler((call) async {
      if (call.method == 'openUnified') _opened.add(null);
    }),
  );

  @override
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> start(ListeningNotice notice) async {
    if (!supported) return;
    await channel.invokeMethod<void>('start', {'channel': notice.channel, 'title': notice.title, 'text': notice.text});
  }

  @override
  Future<void> stop() async {
    if (supported) await channel.invokeMethod<void>('stop');
  }

  @override
  Future<void> requestBatteryExemption() async {
    if (supported) await channel.invokeMethod<bool>('requestBatteryExemption');
  }

  @override
  Stream<void> get opened => _opened.stream;
}
