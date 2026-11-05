import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/core/domain/settings_sync_account_use_case.dart';
import 'package:postino/main.dart';

import '../../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async {
    h = await Harness.create();
    await h.addAccount('a1');
  });

  test('choosing an Account asks Drive, then remembers the choice', () async {
    h.consent.address = 'a1@example.com';
    final r = await getIt<SettingsSyncAccountUseCase>().choose('a1');
    expect(r, isA<Ok<void>>());
    expect(h.consent.lastDrive, isTrue);
    expect(await getIt<SettingsRepository>().settingsSyncAccount(), 'a1');
  });

  test('a denied consent leaves the choice as it was', () async {
    h.consent.failure = const DriveScopeFailure();
    final r = await getIt<SettingsSyncAccountUseCase>().choose('a1');
    expect((r as Err).failure, isA<DriveScopeFailure>());
    expect(await getIt<SettingsRepository>().settingsSyncAccount(), isNull);
  });

  test('Nessuno turns sync off without asking Google', () async {
    await getIt<SettingsRepository>().setSettingsSyncAccount('a1');
    final r = await getIt<SettingsSyncAccountUseCase>().choose(null);
    expect(r, isA<Ok<void>>());
    expect(h.consent.lastDrive, isNull);
    expect(await getIt<SettingsRepository>().settingsSyncAccount(), isNull);
  });
}
