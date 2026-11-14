import 'package:flutter/services.dart';

import '../../domain/app_updater.dart';

/// macOS (Sparkle 2, `macos/Runner/Updater.swift`): the runner answers on [channel]. Sparkle checks on its own and
/// shows its own window, so no Banner.
class const ChannelAppUpdater() implements AppUpdater {
  /// The runner's channel: `checkForUpdates`.
  static const channel = MethodChannel('it.postino/updater');

  @override
  bool get supported => true;

  @override
  AppUpdate? get available => null;

  @override
  Stream<AppUpdate?> get changes => const Stream.empty();

  @override
  Future<void> checkDaily() async {}

  @override
  Future<UpdateCheck> checkForUpdates() async {
    await channel.invokeMethod<void>('checkForUpdates');
    return UpdateCheck.shown;
  }

  @override
  Future<void> dismiss() async {}

  @override
  Future<void> download() async {}
}
