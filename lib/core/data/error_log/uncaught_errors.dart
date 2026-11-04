import 'package:flutter/foundation.dart';

import '../../domain/error_log.dart';

/// Sends the Dart errors nobody caught to [log] as crashes (#116): the framework's (build, layout, gestures) and
/// the async ones of the main isolate, which `PlatformDispatcher.onError` sees without a `runZonedGuarded`.
/// The handling that was there before still runs. Native crashes are not caught (out of scope of #28).
void captureUncaughtErrors(ErrorLog log) {
  final framework = FlutterError.onError;
  FlutterError.onError = (details) {
    // Silent: the framework itself does not count it as a failure (e.g. an image that does not load).
    log.record(details.exception, stack: details.stack, context: 'flutter', crash: !details.silent);
    framework?.call(details);
  };
  final platform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    log.record(error, stack: stack, context: 'uncaught', crash: true);
    return platform?.call(error, stack) ?? false;
  };
}
