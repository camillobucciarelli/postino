// Notifiche immediate (#214): at every start of the app the service comes back only when the choice is on.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/device_settings_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/immediate_notifications_use_case.dart';

import '../../support/fake_immediate_notifications.dart';

void main() {
  late PostinoDatabase db;
  late DeviceSettingsStore settings;
  late FakeImmediateNotifications os;
  late ImmediateNotificationsUseCase useCase;
  const notice = (channel: 'c', title: 't', text: 'x');
  setUp(() {
    db = PostinoDatabase.inMemory();
    settings = DeviceSettingsStore(db);
    os = FakeImmediateNotifications()..supported = true;
    useCase = ImmediateNotificationsUseCase(os, settings);
  });
  tearDown(() => db.close());

  test('never chosen: off, and the start of the app only makes sure the service is stopped', () async {
    expect(await useCase.isEnabled(), isFalse);
    await useCase.resume(notice);
    expect(os.calls, [false]);
  });

  test('on: the start of the app starts the service again, with the texts of now', () async {
    await useCase.setEnabled(enabled: true, notice: notice);
    await useCase.resume((channel: 'c', title: 'T', text: 'X'));
    expect(os.calls, [true, true]);
    expect(os.notice?.title, 'T');
    expect(os.exemptionRequests, 1, reason: 'the exemption is asked from the switch only');
  });

  test('turned off: the start of the app leaves it off', () async {
    await useCase.setEnabled(enabled: true, notice: notice);
    await useCase.setEnabled(enabled: false, notice: notice);
    await useCase.resume(notice);
    expect(os.calls, [true, false, false]);
  });

  test('the battery exemption failing: the service runs and the choice stays on', () async {
    os.exemptionFailure = Exception('no dialog');
    await useCase.setEnabled(enabled: true, notice: notice);
    expect(os.running, isTrue);
    expect(await settings.immediateNotifications(), isTrue);
  });

  test('the service left running by a choice not remembered: stopped at the next start', () async {
    os.running = true;
    await useCase.resume(notice);
    expect(os.running, isFalse);
  });

  test('where unsupported a choice left in the database means nothing', () async {
    await settings.setImmediateNotifications(enabled: true);
    os.supported = false;
    expect(await useCase.isEnabled(), isFalse);
    await useCase.resume(notice);
    expect(os.calls, isEmpty);
  });
}
