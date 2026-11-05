import 'package:flutter/services.dart';

import '../../domain/app_updater.dart';

/// macOS (Sparkle 2, `macos/Runner/Updater.swift`): the runner answers on [channel].
class const ChannelAppUpdater() implements AppUpdater {
  /// The runner's channel: `checkForUpdates`.
  static const channel = MethodChannel('it.postino/updater');

  @override
  bool get supported => true;

  @override
  Future<void> checkForUpdates() => channel.invokeMethod<void>('checkForUpdates');
}
