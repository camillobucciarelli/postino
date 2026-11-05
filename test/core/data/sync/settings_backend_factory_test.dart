// The one place that picks where an Account keeps the Impostazioni di Postino (#124, ADR 0016).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/gmail/drive_settings_backend.dart';
import 'package:postino/core/data/sync/settings_backend_factory.dart';
import 'package:postino/core/domain/platform_services.dart';
import 'package:postino/core/domain/settings_backend.dart';

import '../../../support/fake_platform.dart';
import '../../../support/fake_settings_backend.dart';

void main() {
  final g = GetIt.I;
  setUp(() {
    g
      ..registerSingleton<SecureStore>(FakeSecureStore())
      ..registerSingleton<http.Client>(MockClient((_) async => http.Response('', 500)))
      ..registerSingleton<Clock>(FakeClock(DateTime.utc(2026, 11, 5)));
  });
  tearDown(g.reset);

  test('an Account gets its Drive file, one backend per Account', () {
    final a1 = settingsBackendFor('gmail:a1');
    expect(a1, isA<DriveSettingsBackend>());
    expect(settingsBackendFor('gmail:a1'), same(a1));
    expect(settingsBackendFor('gmail:a2'), isNot(same(a1)));
  });

  test('a backend registered beforehand for the Account is the one used', () {
    final fake = FakeSettingsBackend();
    g.registerSingleton<SettingsBackend>(fake, instanceName: 'gmail:a1');
    expect(settingsBackendFor('gmail:a1'), same(fake));
  });
}
