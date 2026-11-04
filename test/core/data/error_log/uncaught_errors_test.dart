import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/error_log/uncaught_errors.dart';

import '../../../support/fake_platform.dart';

void main() {
  late FlutterExceptionHandler? flutterBefore;
  late ErrorCallback? platformBefore;
  late FakeErrorLog log;
  FakeErrorLog? ready;
  late List<FlutterErrorDetails> forwarded;

  setUp(() {
    flutterBefore = FlutterError.onError;
    platformBefore = PlatformDispatcher.instance.onError;
    forwarded = [];
    FlutterError.onError = forwarded.add;
    log = FakeErrorLog();
    ready = log;
    captureUncaughtErrors(() => ready);
  });

  tearDown(() {
    FlutterError.onError = flutterBefore;
    PlatformDispatcher.instance.onError = platformBefore;
  });

  test('a framework error is recorded as a crash and still reaches the previous handler', () {
    final details = FlutterErrorDetails(exception: StateError('build'));
    FlutterError.onError!(details);
    expect(log.entries, [(details.exception, true)]);
    expect(forwarded, [details]);
  });

  test('a silent framework error is recorded, but is not a crash', () {
    FlutterError.onError!(FlutterErrorDetails(exception: StateError('immagine'), silent: true));
    expect(log.entries.single.$2, isFalse);
  });

  test('an uncaught async error is recorded as a crash and left to the default handling', () {
    final error = StateError('async');
    expect(PlatformDispatcher.instance.onError!(error, StackTrace.current), isFalse);
    expect(log.entries, [(error, true)]);
  });

  test('before the log exists an error still reaches the previous handler, and nothing breaks', () {
    ready = null;
    final details = FlutterErrorDetails(exception: StateError('avvio'));
    FlutterError.onError!(details);
    expect(PlatformDispatcher.instance.onError!(StateError('avvio'), StackTrace.current), isFalse);
    expect(forwarded, [details]);
    expect(log.entries, isEmpty);
  });
}
