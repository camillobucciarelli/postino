// The one place that picks an Account's adapter (ADR 0002), its per-Provider choices (#166), and what a removal
// does to it (#142, ADR 0016).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/account_settings_json.dart';
import 'package:postino/core/data/accounts_settings_mirror.dart';
import 'package:postino/core/data/imap/imap_provider.dart';
import 'package:postino/core/data/imap/imap_session.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync/provider_factory.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/platform_services.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_entry.dart';
import 'package:postino/main.dart';

import '../../../support/fake_platform.dart';
import '../../../support/harness.dart';
import '../../../support/recorded_imap_server.dart';

void main() {
  group('per-Provider choices', () {
    final g = GetIt.I;
    setUp(() {
      g
        ..registerSingleton<SecureStore>(FakeSecureStore())
        ..registerSingleton<Clock>(FakeClock(DateTime.utc(2026, 11, 7)));
    });
    tearDown(g.reset);

    ImapProvider imapOf(ProviderKind kind) =>
        providerFor(Account(id: '${kind.name}:a', address: 'a@example.com', provider: kind, color: 0, position: 0))
            as ImapProvider;

    test('a generic IMAP Account APPENDs its sent messages to Inviati', () {
      expect(imapOf(ProviderKind.imap).appendToSent, isTrue);
    });

    // To confirm with the manual check on the iCloud test Account (#28): flip it if iCloud files SMTP submissions.
    test('iCloud APPENDs its sent messages to Inviati too, until the manual check says otherwise', () {
      expect(imapOf(ProviderKind.icloud).appendToSent, isTrue);
    });
  });

  group('removal of the Account', () {
    test('after the removal of its Account, providerFor makes a new adapter', () async {
      await Harness.create();
      const imap = Account(
        id: 'imap:ada@example.org',
        address: 'ada@example.org',
        provider: ProviderKind.imap,
        color: 0,
        position: 0,
      );
      final db = getIt<PostinoDatabase>();
      await db.accountsDao.upsert(imap);
      final before = providerFor(imap);
      expect(providerFor(imap), same(before));

      await db.postinoSettingsDao.applyRemote([
        SettingsEntry(key: accountSettingsKey(imap.id), value: null, updatedAt: 1, deviceId: 'z', deleted: true),
      ]);
      await getIt<AccountsSettingsMirror>().reconcile();

      expect(await db.accountsDao.exists(imap.id), isFalse);
      expect(providerFor(imap), isNot(same(before)));
    });

    test('the removal of an IMAP Account closes its open session', () async {
      final h = await Harness.create();
      final server = await RecordedImapServer.start((c) => basics(c, capabilities: 'IMAP4rev1')!);
      addTearDown(server.stop);
      getIt
        ..unregister<ImapConnector>()
        ..registerSingleton<ImapConnector>(plainConnector);
      const imap = Account(
        id: 'imap:ada@example.org',
        address: 'ada@example.org',
        provider: ProviderKind.imap,
        color: 0,
        position: 0,
      );
      await server.remember(h.keychain, imap.id);
      final db = getIt<PostinoDatabase>();
      await db.accountsDao.upsert(imap);
      expect(await providerFor(imap).refreshAuth(), isA<Ok<void>>());
      expect(server.commands.where((c) => c.startsWith('LOGIN')), hasLength(1));

      await db.postinoSettingsDao.applyRemote([
        SettingsEntry(key: accountSettingsKey(imap.id), value: null, updatedAt: 1, deviceId: 'z', deleted: true),
      ]);
      await getIt<AccountsSettingsMirror>().reconcile();

      expect(server.commands, contains('LOGOUT'));
    });
  });
}
