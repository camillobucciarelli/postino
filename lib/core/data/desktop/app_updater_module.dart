import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../domain/app_updater.dart';
import 'channel_app_updater.dart';

/// The updater of this platform (#122): Sparkle on macOS; Windows and Linux are left for later.
@module
abstract class AppUpdaterModule() {
  @LazySingleton(env: [Environment.prod])
  AppUpdater appUpdater() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS ? const ChannelAppUpdater() : const _Unsupported();
}

class const _Unsupported() implements AppUpdater {
  @override
  bool get supported => false;

  @override
  Future<void> checkForUpdates() async {}
}
