import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

/// The system's Indietro as Android 16 delivers it (predictive back with targetSdk 36, #365): to the app only
/// when the app declared it handles it (`SystemNavigator.setFrameworkHandlesBack`), otherwise Android leaves
/// the app itself and the app never hears of it.
class SystemBack() {
  /// What the app last declared to Android.
  bool frameworkHandlesBack = false;

  /// How many times the app was left: by Android, or by the app asking (`SystemNavigator.pop`).
  int exits = 0;

  /// Mocks the `flutter/platform` channel for this test; call it before pumping the app.
  /// [resumed] false: the app is built before Android resumes it (a cold start), the test resumes it.
  static SystemBack install(WidgetTester tester, {bool resumed = true}) {
    final back = SystemBack();
    // The app tells Android only once it runs: a test starts with no lifecycle state.
    if (resumed) tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'SystemNavigator.setFrameworkHandlesBack':
          back.frameworkHandlesBack = call.arguments as bool;
        case 'SystemNavigator.pop':
          back.exits++;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    return back;
  }

  /// One Indietro.
  Future<void> press(WidgetTester tester) async {
    if (frameworkHandlesBack) {
      await tester.binding.handlePopRoute();
    } else {
      exits++;
    }
    await tester.pumpAndSettle();
  }
}
