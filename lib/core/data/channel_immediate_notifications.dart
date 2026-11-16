import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../domain/immediate_notifications.dart';

/// Android's Notifiche immediate (#214): `ListeningService`, the `specialUse` foreground service that keeps the app's
/// engine, and with it this isolate's SyncEngine (IDLE, the 60 s poll), alive with Postino closed. Nothing elsewhere.
@LazySingleton(as: ImmediateNotifications, env: [Environment.prod])
class ChannelImmediateNotifications() implements ImmediateNotifications {
  /// The fixed notification's taps are heard from the start.
  this {
    // At once, not at the first listener: the engine started by the service after a reboot runs this before the app
    // is on screen, and the tap that opens it arrives before the router listens ([_pending]).
    channel.setMethodCallHandler((call) async {
      if (call.method != 'openUnified') return;
      _opened.hasListener ? _opened.add(null) : _pending = true;
    });
  }

  /// The runner's channel (`PostinoEngine.kt`): `start({channel, title, text})`, `stop`, `requestBatteryExemption`;
  /// from the runner `openUnified`.
  static const channel = MethodChannel('it.postino/immediate_notifications');

  late final StreamController<void> _opened = StreamController<void>.broadcast(
    onListen: () {
      if (!_pending) return;
      _pending = false;
      scheduleMicrotask(() => _opened.add(null));
    },
  );

  /// The fixed notification tapped while nobody listened: given to the first listener.
  var _pending = false;

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
    if (supported) await channel.invokeMethod<void>('requestBatteryExemption');
  }

  /// `--flavor store`, whose manifest lacks the dialog's permission (ADR 0023).
  @override
  bool get exemptionInSettings => appFlavor == 'store';

  @override
  Stream<void> get opened => _opened.stream;
}
