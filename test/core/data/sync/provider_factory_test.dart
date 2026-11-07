// The adapters of the Accounts (ADR 0002), and what a removal does to them (#142, ADR 0016).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/account_settings_json.dart';
import 'package:postino/core/data/accounts_settings_mirror.dart';
import 'package:postino/core/data/imap/imap_session.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync/provider_factory.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_entry.dart';
import 'package:postino/main.dart';

import '../../../support/harness.dart';
import '../../../support/recorded_imap_server.dart';

void main() {
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
}
