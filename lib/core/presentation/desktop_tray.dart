import 'dart:async';

import '../domain/app_window.dart';
import '../domain/system_tray.dart';

/// Close to tray (#38): closing the window hides it and the process, with its sync, keeps running; the tray's
/// menu shows the window again or quits. Without a tray (it failed to show) closing is the platform's again: it quits
/// on Windows and Linux, and on macOS the Dock icon brings the window back.
class DesktopTray(final AppWindow _window, final SystemTray _tray) {
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Puts the icon in the tray, then keeps the window from closing. [beforeQuit] runs before «Esci» ends the process.
  /// A window [hidden] at launch (#239) is shown when the tray fails, or nothing could bring it back.
  Future<void> start({
    required String tooltip,
    required String openLabel,
    required String quitLabel,
    required Future<void> Function() beforeQuit,
    bool hidden = false,
  }) async {
    _subscriptions.add(
      _tray.commands.listen(
        (command) => unawaited(switch (command) {
          TrayCommand.open => _window.show(),
          TrayCommand.quit => _quit(beforeQuit),
        }),
      ),
    );
    try {
      await _tray.show(tooltip: tooltip, openLabel: openLabel, quitLabel: quitLabel);
    } on Object {
      if (hidden) await _window.show();
      rethrow;
    }
    _subscriptions.add(_window.interceptClose().listen((_) => unawaited(_window.hide())));
  }

  Future<void> _quit(Future<void> Function() beforeQuit) async {
    // ponytail: the process ends anyway; a failing cleanup must not keep it alive.
    try {
      await _tray.hide();
      await beforeQuit();
    } finally {
      await _window.quit();
    }
  }

  /// Stops listening to the window and the tray.
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
  }
}
