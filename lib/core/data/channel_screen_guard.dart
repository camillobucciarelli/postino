import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../domain/screen_guard.dart';

/// The runners answer on [channel]: Android (`FLAG_SECURE`), Windows (`WDA_EXCLUDEFROMCAPTURE`), macOS
/// (`sharingType`), iOS (`UIScreen.isCaptured`). Linux has no handler: no protection there.
@LazySingleton(as: ScreenGuard, env: [Environment.prod])
class ChannelScreenGuard() implements ScreenGuard {
  /// `protect(bool)` → bool (captured now, iOS); the runner calls `captured(bool)` at every change (iOS).
  static const channel = MethodChannel('it.postino/screen_guard');

  final _captured = StreamController<bool>.broadcast();
  var _listening = false;

  @override
  Future<bool> protect({required bool on}) async {
    if (!_listening) {
      _listening = true;
      channel.setMethodCallHandler((call) async {
        if (call.method == 'captured') _captured.add(call.arguments == true);
      });
    }
    try {
      return await channel.invokeMethod<bool>('protect', on) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      // ponytail: best effort, the screen closes itself after two minutes anyway.
      debugPrint('[screen_guard] ${e.code}');
      return false;
    }
  }

  @override
  Stream<bool> watchCaptured() => _captured.stream;
}
