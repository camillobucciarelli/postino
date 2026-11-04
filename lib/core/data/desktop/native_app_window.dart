import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:window_manager/window_manager.dart';

import '../../domain/app_window.dart';

/// The window through window_manager's native API (nativeapi), resolved once, when this is built: nativeapi's
/// "current" window is the active one (Windows: GetActiveWindow), which a hidden window never is, and on macOS the
/// tray's own status item may come first. So it is built after the first frame and before the tray.
@LazySingleton(as: AppWindow, env: [Environment.prod])
class NativeAppWindow() implements AppWindow {
  final Window _window = _resolve();

  /// Like nativeapi_flutter's DropRegion: the active window, else the app's only one.
  static Window _resolve() {
    const manager = WindowManager.instance;
    if (manager.getCurrent() case final current?) return current;
    final all = manager.getAll();
    return all.length == 1 ? all.single : throw StateError('no window');
  }

  @override
  Stream<void> interceptClose() {
    // ignore: close_sinks, lives as long as the process: the window it listens to never goes away.
    final requests = StreamController<void>.broadcast();
    _window.addListener((event) {
      if (event is WindowCloseRequestedEvent) {
        event.request.cancel();
        requests.add(null);
      }
    });
    return requests.stream;
  }

  @override
  Future<void> show() async {
    _window
      ..show()
      ..focus();
  }

  @override
  Future<void> hide() async => _window.hide();

  // ponytail: exit() and not the platform's own termination; the caller stops the sync and closes the database
  // first, nothing else holds state. Use NSApp.terminate / PostQuitMessage over a channel if a plugin ever needs its shutdown hooks.
  @override
  Future<void> quit() async => exit(0);
}
