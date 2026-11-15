// Repro: sync on on both devices, A connects a new Account, B (running, never restarted) must get it through the
// real triggers only (debounce after the local write on A, poll on B): no manual syncNow.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/accounts_lock.dart';
import 'package:postino/core/data/accounts_settings_mirror.dart';
import 'package:postino/core/data/device_settings_store.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/settings_sync.dart';
import 'package:postino/core/domain/accounts_repository.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/main.dart';

import '../../support/fake_platform.dart';
import '../../support/fake_settings_backend.dart';
import '../../support/harness.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> settle(Harness h, Duration d) async {
    await pumpEventQueue();
    h.clock.advance(d);
    await pumpEventQueue(times: 50);
  }

  for (final kind in ['gmail', 'icloud']) {
    test('A connects a new $kind Account with the sync on: running B gets it from the triggers alone', () async {
      final file = FakeSettingsBackend();
      // Device A: the app in the DI, ada connected and chosen as the sync Account, SettingsSync started as main.dart.
      final h = await Harness.create();
      await getIt.unregister<SettingsSync>();
      getIt.registerLazySingleton<SettingsSync>(
        () => SettingsSync(
          getIt<PostinoDatabase>(),
          getIt<SettingsRepository>(),
          h.clock,
          h.connectivity,
          backendFor: (_) => file,
        ),
      );
      h.providerFor('gmail:ada@gmail.com');
      await getIt<AccountsRepository>().connectGmail();
      await getIt<SettingsRepository>().setSettingsSyncAccount('gmail:ada@gmail.com');
      getIt<SettingsSync>().start();
      addTearDown(() => getIt<SettingsSync>().stop());
      await settle(h, Duration.zero);

      // Device B: its own database on the same file and clock, sync on the same Account, started as main.dart.
      final bDb = PostinoDatabase.inMemory();
      final bSettings = DeviceSettingsStore(bDb);
      await bSettings.setSettingsSyncAccount('gmail:ada@gmail.com');
      final bSync = SettingsSync(bDb, bSettings, h.clock, FakeConnectivity(), backendFor: (_) => file)..start();
      final bMirror = AccountsSettingsMirror(
        bDb,
        MailStore(bDb),
        FakeSecureStore(),
        bSettings,
        AccountsLock(),
        FakeAttachments(),
      )..start();
      addTearDown(() async {
        await bMirror.stop();
        await bSync.stop();
        await bDb.close();
      });
      await settle(h, Duration.zero);
      expect((await MailStore(bDb).accounts()).map((a) => a.id), ['gmail:ada@gmail.com']);

      // A adds a new address, then the debounce on A and one poll on B pass.
      if (kind == 'gmail') {
        h
          ..providerFor('gmail:bob@gmail.com')
          ..consent.address = 'bob@gmail.com';
        await getIt<AccountsRepository>().connectGmail();
      } else {
        h.providerFor('icloud:bob@icloud.com');
        await getIt<AccountsRepository>().connectWithPassword('bob@icloud.com', 'app-password-1');
      }
      await settle(h, settingsDebounce);
      await settle(h, settingsPollEvery);

      expect(
        (await MailStore(bDb).accounts()).map((a) => a.id),
        containsAll(['gmail:ada@gmail.com', kind == 'gmail' ? 'gmail:bob@gmail.com' : 'icloud:bob@icloud.com']),
      );
    });
  }
}
