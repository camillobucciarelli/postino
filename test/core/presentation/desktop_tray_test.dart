// Close to tray (#38): closing hides, the tray's menu opens and quits; without a tray, closing is left alone.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/app_window.dart';
import 'package:postino/core/domain/system_tray.dart';
import 'package:postino/core/presentation/desktop_tray.dart';

class _FakeWindow() implements AppWindow {
  final calls = <String>[];
  final _close = StreamController<void>.broadcast();
  var intercepting = false;

  void requestClose() => _close.add(null);

  @override
  Stream<void> interceptClose() {
    intercepting = true;
    return _close.stream;
  }

  @override
  Future<void> show() async => calls.add('show');

  @override
  Future<void> hide() async => calls.add('hide');

  @override
  Future<void> quit() async => calls.add('quit');
}

class _FakeTray(final List<String> _calls) implements SystemTray {
  final _commands = StreamController<TrayCommand>.broadcast();

  @override
  Future<void> hide() async => _calls.add('trayHide');
  (String, String, String)? shown;
  Object? failure;

  void choose(TrayCommand c) => _commands.add(c);

  @override
  Stream<TrayCommand> get commands => _commands.stream;

  @override
  Future<void> show({required String tooltip, required String openLabel, required String quitLabel}) async {
    if (failure case final f?) throw f;
    shown = (tooltip, openLabel, quitLabel);
  }
}

void main() {
  late _FakeWindow window;
  late _FakeTray tray;
  late DesktopTray desktop;
  late List<String> calls;
  setUp(() {
    window = _FakeWindow();
    calls = window.calls;
    tray = _FakeTray(calls);
    desktop = DesktopTray(window, tray);
  });
  tearDown(() => desktop.dispose());

  Future<void> start() => desktop.start(
    tooltip: 'Postino',
    openLabel: 'Apri Postino',
    quitLabel: 'Esci',
    beforeQuit: () async => calls.add('beforeQuit'),
  );

  test('the tray shows its menu, and closing the window only hides it', () async {
    await start();
    expect(tray.shown, ('Postino', 'Apri Postino', 'Esci'));
    window.requestClose();
    await pumpEventQueue();
    expect(calls, ['hide']);
  });

  test('«Apri Postino» shows the window again', () async {
    await start();
    window.requestClose();
    tray.choose(TrayCommand.open);
    await pumpEventQueue();
    expect(calls, ['hide', 'show']);
  });

  test('«Esci» cleans up, then ends the process', () async {
    await start();
    tray.choose(TrayCommand.quit);
    await pumpEventQueue();
    // The icon goes first: Windows would keep a ghost of it after the process ends.
    expect(calls, ['trayHide', 'beforeQuit', 'quit']);
  });

  test('«Esci» ends the process even when the clean-up fails', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      await desktop.start(
        tooltip: 'Postino',
        openLabel: 'Apri Postino',
        quitLabel: 'Esci',
        beforeQuit: () async => throw StateError('db'),
      );
      tray.choose(TrayCommand.quit);
      await pumpEventQueue();
    }, (e, _) => errors.add(e));
    expect(calls, ['trayHide', 'quit']);
    expect(errors, [isA<StateError>()]);
  });

  test('without a tray the window keeps closing as the platform does', () async {
    tray.failure = StateError('no tray');
    await expectLater(start(), throwsStateError);
    expect(window.intercepting, isFalse);
  });
}
