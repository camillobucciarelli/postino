// Password Accounts (#162): iCloud preset, IMAP autodiscovery or manual servers, test connection, keychain only.

import 'package:flutter_test/flutter_test.dart';
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

  test('a mailbox already connected with Gmail is not added again over IMAP', () async {
    h.providerFor('gmail:ada@company.com');
    h.consent.address = 'ada@company.com';
    await accounts.connectGmail();
    h.discovery.servers['ada@company.com'] = _fastmail;

    final r = await accounts.connectWithPassword('ada@company.com', 'app-password-1');

    expect(_failure(r), isA<AlreadyConnectedFailure>());
    expect(h.connection.tested, isEmpty);
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

  test('without an IMAP adapter the Account syncs nothing and stays attivo; the password is never logged', () async {
    await accounts.connectWithPassword('ada@icloud.com', 'wrong');
    await accounts.connectWithPassword('ada@icloud.com', 'app-password-1');
    await getIt<SyncEngine>().syncAll();

    expect((await getIt<MailStore>().accounts()).single.status, AccountStatus.attivo);
    final log = await getIt<ErrorLog>().read();
    expect(log, isNot(contains('app-password-1')));
    expect(log, isNot(contains('wrong')));
  });
}
