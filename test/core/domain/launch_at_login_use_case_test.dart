// Avvio al login on by default (#38): the first run turns it on, never again after a choice.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/device_settings_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/launch_at_login_use_case.dart';

import '../../support/fake_platform.dart';

void main() {
  late PostinoDatabase db;
  late DeviceSettingsStore settings;
  late FakeLaunchAtLogin os;
  late LaunchAtLoginUseCase useCase;
  setUp(() {
    db = PostinoDatabase.inMemory();
    settings = DeviceSettingsStore(db);
    os = FakeLaunchAtLogin()..supported = true;
    useCase = LaunchAtLoginUseCase(os, settings);
  });
  tearDown(() => db.close());

  test('the first run turns it on and remembers it', () async {
    await useCase.applyDefault();
    expect(os.enabled, isTrue);
    expect(await settings.launchAtLogin(), isTrue);
  });

  test('a later run leaves the choice alone, even when the user turned it off from the system', () async {
    await useCase.applyDefault();
    os.enabled = false;
    await useCase.applyDefault();
    expect(os.enabled, isFalse);
    expect(os.changes, [true]);
  });

  test('turned off from the switch, it stays off at the next run', () async {
    await useCase.applyDefault();
    await useCase.setEnabled(enabled: false);
    await useCase.applyDefault();
    expect(os.enabled, isFalse);
    expect(await settings.launchAtLogin(), isFalse);
  });

  test('a refusal of the OS is not remembered: the next run tries again', () async {
    os.failure = Exception('refused');
    await expectLater(useCase.applyDefault(), throwsException);
    expect(await settings.launchAtLogin(), isNull);
    os.failure = null;
    await useCase.applyDefault();
    expect(os.enabled, isTrue);
  });

  test('nothing happens where the platform has none', () async {
    os.supported = false;
    await useCase.applyDefault();
    expect(os.changes, isEmpty);
    expect(await settings.launchAtLogin(), isNull);
  });
}
