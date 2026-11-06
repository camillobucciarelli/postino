import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/accounts_settings_mirror.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/accounts_repository.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_entry.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/main.dart';

import '../../support/harness.dart';

void main() {
  _driveTests();
  test('tokens go only to the keychain, never to the database', () async {
    final h = await Harness.create();
    h.providerFor('gmail:ada@gmail.com');

    await getIt<AccountsRepository>().connectGmail();

    final kept = h.keychain.values.values.join();
    expect(kept, contains('access-token-1'));
    expect(kept, contains('refresh-token-1'));

    final db = getIt<PostinoDatabase>();
    final tables = await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'table'").get();
    final stored = [
      for (final t in tables)
        for (final row in await db.customSelect('SELECT * FROM "${t.read<String>('name')}"').get()) ...row.data.values,
    ].join('|');
    expect(stored, contains('ada@gmail.com'), reason: 'the Account is there');
    expect(stored, isNot(contains('token')));
  });

  test('reconnecting with another Google identity writes nothing', () async {
    final h = await Harness.create();
    h.providerFor('gmail:ada@gmail.com');
    final accounts = getIt<AccountsRepository>();
    await accounts.connectGmail();
    final keychainBefore = Map.of(h.keychain.values);

    h.consent.address = 'bob@gmail.com';
    final r = await accounts.connectGmail(loginHint: 'Ada@Gmail.com');

    expect(r, isA<Err<Object>>());
    expect((r as Err).failure, isA<WrongAccountFailure>().having((f) => f.expected, 'expected', 'Ada@Gmail.com'));
    expect(h.keychain.values, keychainBefore);
    final all = await getIt<MailStore>().accounts();
    expect(all.map((a) => a.id), ['gmail:ada@gmail.com']);
  });

  test('the same address in another case still reconnects', () async {
    final h = await Harness.create();
    h.providerFor('gmail:ada@gmail.com');
    final accounts = getIt<AccountsRepository>();
    await accounts.connectGmail();

    final r = await accounts.connectGmail(loginHint: 'ADA@gmail.com');

    expect(r, isA<Ok<Object>>());
  });

  test('reconnecting with the grant in another case keeps the same Account', () async {
    final h = await Harness.create();
    h.providerFor('gmail:ada@gmail.com');
    final accounts = getIt<AccountsRepository>();
    final store = getIt<MailStore>();
    await accounts.connectGmail();
    await store.setStatus('gmail:ada@gmail.com', AccountStatus.daRicollegare);
    h.keychain.values.clear();

    h.consent.address = 'Ada@Gmail.com';
    final r = await accounts.connectGmail(loginHint: 'ada@gmail.com');

    expect(r, isA<Ok<Object>>());
    final all = await store.accounts();
    expect(all.map((a) => a.id), ['gmail:ada@gmail.com']);
    expect(all.single.status, AccountStatus.attivo);
    expect(h.keychain.values.keys, ['oauth:gmail:ada@gmail.com']);
  });

  test('a new Account goes after the last one and writes its synced voce', () async {
    final h = await Harness.create();
    // Positions with a gap, as after a removal: a count would collide with the last one.
    await h.addAccount('a1');
    await h.addAccount('a2');
    await getIt<PostinoDatabase>().accountsDao.remove('a1');
    h.providerFor('gmail:ada@gmail.com');

    await getIt<AccountsRepository>().connectGmail();

    final ada = (await getIt<MailStore>().accounts()).last;
    expect((ada.id, ada.position), ('gmail:ada@gmail.com', 2));
    final voce = await getIt<PostinoDatabase>().postinoSettingsDao.readRow('accounts/gmail:ada@gmail.com');
    expect(jsonDecode(voce!.value!), {'address': 'ada@gmail.com', 'provider': 'gmail', 'color': 1, 'position': 2});
    expect(voce.dirty, isTrue);
  });

  test('a new Account with the sync on is stamped now, with the sync off before any synced copy', () async {
    final h = await Harness.create();
    h
      ..providerFor('gmail:ada@gmail.com')
      ..providerFor('gmail:bob@gmail.com');
    final dao = getIt<PostinoDatabase>().postinoSettingsDao;
    await getIt<AccountsRepository>().connectGmail();
    final off = await dao.readRow('accounts/gmail:ada@gmail.com');
    expect((off!.updatedAt, off.deviceId, off.dirty), (0, '', true));

    await getIt<SettingsRepository>().setSettingsSyncAccount('gmail:ada@gmail.com');
    h.consent.address = 'bob@gmail.com';
    await getIt<AccountsRepository>().connectGmail();
    final on = await dao.readRow('accounts/gmail:bob@gmail.com');
    expect((on!.updatedAt, on.dirty), (h.clock.now().millisecondsSinceEpoch, true));
  });

  test('reconnecting an Account whose voce says something else writes it again, newer and to upload', () async {
    final h = await Harness.create();
    h.providerFor('gmail:ada@gmail.com');
    final accounts = getIt<AccountsRepository>();
    await accounts.connectGmail();
    final db = getIt<PostinoDatabase>();
    await db.postinoSettingsDao.markClean(await db.postinoSettingsDao.entries());
    final before = (await db.postinoSettingsDao.readRow('accounts/gmail:ada@gmail.com'))!;
    final ada = (await getIt<MailStore>().accounts()).single;
    await db.accountsDao.updateSettings(
      Account(id: ada.id, address: ada.address, provider: ada.provider, color: 5, position: ada.position),
    );

    h.clock.advance(const Duration(minutes: 1));
    await accounts.connectGmail(loginHint: 'ada@gmail.com');

    final after = (await db.postinoSettingsDao.readRow('accounts/gmail:ada@gmail.com'))!;
    expect((jsonDecode(after.value!) as Map<String, dynamic>)['color'], 5);
    expect(after.updatedAt, greaterThan(before.updatedAt));
    expect(after.dirty, isTrue);
  });

  test('a reconnection while the same Account is being removed ends with Account and tokens, or neither', () async {
    final h = await Harness.create();
    h.providerFor('gmail:ada@gmail.com');
    await getIt<AccountsRepository>().connectGmail();
    // Its first mail sync over.
    await pumpEventQueue();
    final db = getIt<PostinoDatabase>();
    // A tombstone from another device, newer than the voce here.
    await db.postinoSettingsDao.applyRemote([
      SettingsEntry(
        key: 'accounts/gmail:ada@gmail.com',
        value: null,
        updatedAt: h.clock.now().millisecondsSinceEpoch + 1000,
        deviceId: 'z',
        deleted: true,
      ),
    ]);

    // The mirror is deleting the credentials when the OAuth of a reconnection comes back.
    final gate = h.keychain.deleteGate = Completer<void>();
    final removal = getIt<AccountsSettingsMirror>().reconcile();
    await pumpEventQueue();
    final reconnection = getIt<AccountsRepository>().connectGmail(loginHint: 'ada@gmail.com');
    await pumpEventQueue();
    gate.complete();
    await removal;
    await reconnection;

    final accounts = await getIt<MailStore>().accounts();
    final tokens = h.keychain.values.containsKey('oauth:gmail:ada@gmail.com');
    expect(accounts.isNotEmpty, tokens, reason: 'never an Account without its tokens');
    expect(accounts.single.status, AccountStatus.attivo);
  });

  test('reconnecting with nothing changed leaves the synced voce as it was', () async {
    final h = await Harness.create();
    h.providerFor('gmail:ada@gmail.com');
    final accounts = getIt<AccountsRepository>();
    await accounts.connectGmail();
    final dao = getIt<PostinoDatabase>().postinoSettingsDao;
    final before = await dao.readRow('accounts/gmail:ada@gmail.com');

    h.clock.advance(const Duration(minutes: 1));
    await accounts.connectGmail(loginHint: 'ada@gmail.com');

    expect(await dao.readRow('accounts/gmail:ada@gmail.com'), before);
  });

  test('onboarding with a mixed-case address creates a lowercase id', () async {
    final h = await Harness.create();
    h.providerFor('gmail:ada@gmail.com');
    h.consent.address = ' Ada@Gmail.com ';

    await getIt<AccountsRepository>().connectGmail();

    final all = await getIt<MailStore>().accounts();
    expect(all.map((a) => a.id), ['gmail:ada@gmail.com']);
    expect(all.single.address, 'ada@gmail.com');
  });
}

void _driveTests() {
  group('grantDriveAccess', () {
    Future<Harness> connected() async {
      final h = await Harness.create();
      h.providerFor('gmail:ada@gmail.com');
      await getIt<AccountsRepository>().connectGmail();
      return h;
    }

    test('asks Drive for that address and replaces only its tokens', () async {
      final h = await connected();
      final r = await getIt<AccountsRepository>().grantDriveAccess('gmail:ada@gmail.com');

      expect(r, isA<Ok<void>>());
      expect(h.consent.lastDrive, isTrue);
      expect(h.consent.lastLoginHint, 'ada@gmail.com');
      expect(h.keychain.values['oauth:gmail:ada@gmail.com'], contains('refresh-token-2'));
    });

    test('a denial or another identity writes nothing and keeps the Account attivo', () async {
      final h = await connected();
      final before = Map.of(h.keychain.values);

      h.consent.failure = const DriveScopeFailure();
      expect(
        (await getIt<AccountsRepository>().grantDriveAccess('gmail:ada@gmail.com') as Err).failure,
        isA<DriveScopeFailure>(),
      );

      h.consent.failure = null;
      h.consent.address = 'bob@gmail.com';
      expect(
        (await getIt<AccountsRepository>().grantDriveAccess('gmail:ada@gmail.com') as Err).failure,
        isA<WrongAccountFailure>(),
      );

      expect(h.keychain.values, before);
      expect((await getIt<MailStore>().accounts()).single.status, AccountStatus.attivo);
    });

    test('an Account removed during the Drive consent is not found and gets no credentials', () async {
      final h = await connected();
      final gate = Completer<void>();
      h.consent.gate = gate.future;
      final grant = getIt<AccountsRepository>().grantDriveAccess('gmail:ada@gmail.com');
      await pumpEventQueue();
      await h.keychain.delete('oauth:gmail:ada@gmail.com');
      await getIt<PostinoDatabase>().accountsDao.remove('gmail:ada@gmail.com');
      gate.complete();

      expect(((await grant) as Err).failure, isA<NotFoundFailure>());
      expect(h.keychain.values.keys, isNot(contains('oauth:gmail:ada@gmail.com')));
    });

    test('an unknown Account is not found, and Drive is not asked', () async {
      final h = await connected();
      final r = await getIt<AccountsRepository>().grantDriveAccess('gmail:nobody@gmail.com');
      expect((r as Err).failure, isA<NotFoundFailure>());
      expect(h.consent.lastDrive, isFalse, reason: 'only the onboarding ran');
    });
  });
}
