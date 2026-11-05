import 'package:flutter/foundation.dart';

import '../../domain/error_log.dart';

/// Sends the Dart errors nobody caught to the log as crashes (#116): the framework's (build, layout, gestures) and
/// the async ones of the main isolate, which `PlatformDispatcher.onError` sees without a `runZonedGuarded`.
/// Installed before the DI, so it also sees a start that fails: [log] is null until the log exists, and then an error
/// goes only to the handling that was there before, which always still runs. Native crashes are not caught (#28).
void captureUncaughtErrors(ErrorLog? Function() log) {
  final framework = FlutterError.onError;
  FlutterError.onError = (details) {
    // Silent: the framework itself does not count it as a failure (e.g. an image that does not load).
    log()?.record(details.exception, stack: details.stack, context: 'flutter', crash: !details.silent);
    framework?.call(details);
  };
  final platform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    log()?.record(error, stack: stack, context: 'uncaught', crash: true);
    return platform?.call(error, stack) ?? false;
  };
}
