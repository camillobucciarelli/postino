// Password Accounts (#162): iCloud preset, IMAP autodiscovery or manual servers, test connection, keychain only.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/account_settings_json.dart';
import 'package:postino/core/data/accounts_lock.dart';
import 'package:postino/core/data/imap/password_credentials.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/accounts_repository.dart';
import 'package:postino/core/domain/error_log.dart';
import 'package:postino/core/domain/mail_servers.dart';
import 'package:postino/core/domain/password_provider.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/main.dart';

import '../../support/harness.dart';

const _fastmail = ServerSettings(
  imap: MailServer(host: 'imap.fastmail.com', port: 993, security: ServerSecurity.ssl),
  smtp: MailServer(host: 'smtp.fastmail.com', port: 465, security: ServerSecurity.ssl),
);

Future<String> _database() async {
  final db = getIt<PostinoDatabase>();
  final tables = await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'table'").get();
  return [
    for (final t in tables)
      for (final row in await db.customSelect('SELECT * FROM "${t.read<String>('name')}"').get()) ...row.data.values,
  ].join('|');
}

Failure _failure(Result<Object> r) => (r as Err).failure;

void main() {
  late Harness h;
  late AccountsRepository accounts;
  setUp(() async {
    h = await Harness.create();
    accounts = getIt<AccountsRepository>();
  });

  test('an iCloud address uses the preset; the password goes only to the keychain', () async {
    final r = await accounts.connectWithPassword(' Ada@iCloud.com ', 'app-password-1');

    final account = (r as Ok<Account>).value;
    expect(account.id, 'icloud:ada@icloud.com');
    expect(account.provider, ProviderKind.icloud);
    expect(h.connection.tested.single, (icloudServers, 'ada@icloud.com'));
    expect(h.discovery.asked, isEmpty);
    final saved = await PasswordCredentials.read(h.keychain, account.id);
    expect(saved?.password, 'app-password-1');
    expect(saved?.servers, icloudServers);
    final stored = await _database();
    expect(stored, contains('ada@icloud.com'));
    expect(stored, isNot(contains('app-password-1')));
  });

  test('me.com and mac.com are iCloud too', () async {
    for (final a in ['bob@me.com', 'eve@mac.com']) {
      final r = await accounts.connectWithPassword(a, 'app-password-1');
      expect((r as Ok<Account>).value.provider, ProviderKind.icloud);
    }
  });

  group('the synced voce (ADR 0016), as connectWithPassword writes it', () {
    Future<PostinoSettingRow?> voce(String id) => getIt<PostinoDatabase>().postinoSettingsDao.readRow('accounts/$id');

    test('iCloud, with the sync off: before the sync, without servers nor password', () async {
      await accounts.connectWithPassword('ada@icloud.com', 'app-password-1');

      final v = (await voce('icloud:ada@icloud.com'))!;
      expect(jsonDecode(v.value!), {'address': 'ada@icloud.com', 'provider': 'icloud', 'color': 0, 'position': 0});
      expect((v.updatedAt, v.deviceId, v.dirty), (0, '', true));
      expect(decodeAccountSettings('icloud:ada@icloud.com', v.value), isNotNull);
    });

    test('IMAP, with the sync on: stamped now', () async {
      await getIt<SettingsRepository>().setSettingsSyncAccount('gmail:x@gmail.com');
      h.discovery.servers['ada@fastmail.com'] = _fastmail;
      await accounts.connectWithPassword('ada@fastmail.com', 'app-password-1');

      final v = (await voce('imap:ada@fastmail.com'))!;
      expect(jsonDecode(v.value!), {'address': 'ada@fastmail.com', 'provider': 'imap', 'color': 0, 'position': 0});
      expect((v.updatedAt, v.dirty), (h.clock.now().millisecondsSinceEpoch, true));
      expect(v.value, isNot(contains('imap.fastmail.com')), reason: 'no server in the voce');
      expect(decodeAccountSettings('imap:ada@fastmail.com', v.value), isNotNull);
    });
  });

  test('another address is IMAP with the discovered servers', () async {
    h.discovery.servers['ada@fastmail.com'] = _fastmail;

    final r = await accounts.connectWithPassword('ada@fastmail.com', 'app-password-1');

    expect((r as Ok<Account>).value.id, 'imap:ada@fastmail.com');
    expect(r.value.provider, ProviderKind.imap);
    expect(h.connection.tested.single.$1, _fastmail);
  });

  test('without discovered servers it asks for them; given by hand they are used', () async {
    final none = await accounts.connectWithPassword('ada@example.org', 'app-password-1');
    expect(_failure(none), isA<ServerNotFoundFailure>());
    expect(h.connection.tested, isEmpty);

    final r = await accounts.connectWithPassword('ada@example.org', 'app-password-1', servers: _fastmail);
    expect(r, isA<Ok<Account>>());
    expect((await PasswordCredentials.read(h.keychain, 'imap:ada@example.org'))?.servers, _fastmail);
  });

  test('every refusal writes nothing', () async {
    h.discovery.servers['ada@fastmail.com'] = _fastmail;
    final cases = <Future<Result<Account>> Function(), Type>{
      () => accounts.connectWithPassword('ada@gmail.com', 'app-password-1'): UseGmailFailure,
      () => accounts.connectWithPassword('ada@icloud.com', 'wrong'): AuthFailure,
      () {
        h.connection.failure = const OfflineFailure();
        return accounts.connectWithPassword('ada@fastmail.com', 'app-password-1');
      }: OfflineFailure,
    };
    for (final MapEntry(key: run, value: type) in cases.entries) {
      expect(_failure(await run()).runtimeType, type);
    }
    expect(h.keychain.values, isEmpty);
    expect(await getIt<MailStore>().accounts(), isEmpty);
  });

  test('an attivo Account is already connected', () async {
    await accounts.connectWithPassword('ada@icloud.com', 'app-password-1');
    final again = await accounts.connectWithPassword('ADA@icloud.com', 'app-password-1');
    expect(_failure(again), isA<AlreadyConnectedFailure>());
  });

  test('the same address with Gmail and over IMAP is two Accounts (ADR 0016)', () async {
    h.providerFor('gmail:ada@company.com');
    h.consent.address = 'ada@company.com';
    await accounts.connectGmail();
    h.discovery.servers['ada@company.com'] = _fastmail;

    final r = await accounts.connectWithPassword('ada@company.com', 'app-password-1');

    expect((r as Ok<Account>).value.id, 'imap:ada@company.com');
    expect((await getIt<MailStore>().accounts()).map((a) => (a.id, a.status)), [
      ('gmail:ada@company.com', AccountStatus.attivo),
      ('imap:ada@company.com', AccountStatus.attivo),
    ]);
  });

  test('the same address over IMAP and then with Gmail is two Accounts too', () async {
    h.discovery.servers['ada@company.com'] = _fastmail;
    await accounts.connectWithPassword('ada@company.com', 'app-password-1');
    h
      ..providerFor('gmail:ada@company.com')
      ..consent.address = 'ada@company.com';

    final r = await accounts.connectGmail();

    expect((r as Ok<Account>).value.id, 'gmail:ada@company.com');
    expect(h.keychain.values.keys, containsAll(['password:imap:ada@company.com', 'oauth:gmail:ada@company.com']));
    expect((await getIt<MailStore>().accounts()).map((a) => a.id), ['imap:ada@company.com', 'gmail:ada@company.com']);
  });

  test('cancelled while waiting for the Accounts lock, nothing is written', () async {
    final busy = Completer<void>();
    final held = getIt<AccountsLock>().run(() => busy.future);
    final cancel = Completer<void>();
    final pending = accounts.connectWithPassword('ada@icloud.com', 'app-password-1', cancel: cancel.future);
    await pumpEventQueue();

    cancel.complete();
    await pumpEventQueue();
    busy.complete();
    await held;

    expect(_failure(await pending), isA<CancelledFailure>());
    expect(h.keychain.values, isEmpty);
    expect(await getIt<MailStore>().accounts(), isEmpty);
  });

  test('the Account removed here while the reconnection waits for the lock: nothing is written', () async {
    await accounts.connectWithPassword('ada@icloud.com', 'app-password-1');
    await getIt<MailStore>().setStatus('icloud:ada@icloud.com', AccountStatus.daRicollegare);
    final busy = Completer<void>();
    final held = getIt<AccountsLock>().run(() => busy.future);
    final pending = accounts.connectWithPassword('ada@icloud.com', 'app-password-1');
    await pumpEventQueue();

    await accounts.remove('icloud:ada@icloud.com');
    busy.complete();
    await held;

    expect(_failure(await pending), isA<CancelledFailure>());
    expect(h.keychain.values.keys.where((k) => k.contains('ada@icloud.com')), isEmpty);
    expect(await getIt<MailStore>().accounts(), isEmpty);
  });

  test('cancelled while the servers answer, nothing is written', () async {
    final cancel = Completer<void>();
    h.connection.gate = Completer<void>();
    final pending = accounts.connectWithPassword('ada@icloud.com', 'app-password-1', cancel: cancel.future);
    await Future<void>.delayed(Duration.zero);

    cancel.complete();
    h.connection.gate!.complete();

    expect(_failure(await pending), isA<CancelledFailure>());
    expect(h.keychain.values, isEmpty);
    expect(await getIt<MailStore>().accounts(), isEmpty);
  });

  test('reconnecting a Da ricollegare Account keeps its servers and brings it back to attivo', () async {
    h.connection.password = 'old';
    await accounts.connectWithPassword('ada@example.org', 'old', servers: _fastmail);
    await getIt<MailStore>().setStatus('imap:ada@example.org', AccountStatus.daRicollegare);
    h.connection.password = 'new';

    final r = await accounts.connectWithPassword('ada@example.org', 'new');

    expect(r, isA<Ok<Account>>());
    expect(h.connection.tested.last.$1, _fastmail);
    expect(h.discovery.asked, isEmpty);
    expect((await getIt<MailStore>().accounts()).single.status, AccountStatus.attivo);
    expect((await PasswordCredentials.read(h.keychain, 'imap:ada@example.org'))?.password, 'new');
  });

  test('a new Account that cannot reach its server stays attivo; the password is never logged', () async {
    await accounts.connectWithPassword('ada@icloud.com', 'wrong');
    await accounts.connectWithPassword('ada@icloud.com', 'app-password-1');
    await getIt<SyncEngine>().syncAll();

    expect((await getIt<MailStore>().accounts()).single.status, AccountStatus.attivo);
    final log = await getIt<ErrorLog>().read();
    expect(log, isNot(contains('app-password-1')));
    expect(log, isNot(contains('wrong')));
  });
}
