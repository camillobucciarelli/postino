import 'dart:io' show Platform;

import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../domain/launch_at_login.dart';
import 'channel_launch_at_login.dart';
import 'xdg_launch_at_login.dart';

/// The avvio al login of this platform (#38): none on mobile.
@module
abstract class LaunchAtLoginModule() {
  @LazySingleton(env: [Environment.prod])
  LaunchAtLogin launchAtLogin() => kIsWeb
      ? const _Unsupported()
      : switch (defaultTargetPlatform) {
          TargetPlatform.macOS || TargetPlatform.windows => ChannelLaunchAtLogin(),
          TargetPlatform.linux => XdgLaunchAtLogin(
            const LocalFileSystem().file('${_xdgConfigHome()}/autostart/postino.desktop'),
            Platform.resolvedExecutable,
          ),
          _ => const _Unsupported(),
        };

  static String _xdgConfigHome() => switch (Platform.environment['XDG_CONFIG_HOME']) {
    final dir? when dir.startsWith('/') => dir,
    _ => '${Platform.environment['HOME']}/.config',
  };
}

class const _Unsupported() implements LaunchAtLogin {
  @override
  bool get supported => false;

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<void> setEnabled({required bool enabled}) async {}
}
