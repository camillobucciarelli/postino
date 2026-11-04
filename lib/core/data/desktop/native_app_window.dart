import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:window_manager/window_manager.dart';

import '../../domain/app_window.dart';

/// The window through window_manager's native API (nativeapi).
@LazySingleton(as: AppWindow, env: [Environment.prod])
class NativeAppWindow() implements AppWindow {
  Window get _window => WindowManager.instance.getCurrent() ?? (throw StateError('no window'));

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
