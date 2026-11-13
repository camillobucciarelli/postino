import 'package:flutter/services.dart';

import '../../domain/launch_at_login.dart';

/// macOS (`SMAppService.mainApp`, from 13) and Windows (`HKCU\…\Run`): the runner answers on [channel].
class ChannelLaunchAtLogin() implements LaunchAtLogin {
  /// The runner's channel: `isEnabled` → bool, `setEnabled(bool)`, `launchedAtLogin` → bool (macOS: the login
  /// item's Apple event; Windows: the Run value's `--hidden`).
  static const channel = MethodChannel('it.postino/launch_at_login');

  // ponytail: macOS 12 answers isEnabled false and refuses setEnabled, so the switch stays off; ask the runner
  // here if it should rather be hidden there.
  @override
  bool get supported => true;

  @override
  Future<bool> isEnabled() async => await channel.invokeMethod<bool>('isEnabled') ?? false;

  @override
  Future<void> setEnabled({required bool enabled}) => channel.invokeMethod<void>('setEnabled', enabled);

  @override
  Future<bool> launchedAtLogin() async => await channel.invokeMethod<bool>('launchedAtLogin') ?? false;
}
