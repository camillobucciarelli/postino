// Collegare un Account Microsoft personale (#179): consent, keychain, ricollegamento, rimozione.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/accounts_repository.dart';
import 'package:postino/core/domain/mail_servers.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/main.dart';

import '../../support/harness.dart';

const _id = 'microsoft:ada@outlook.com';

Failure _failure(Result<Object> r) => (r as Err<Object>).failure;

void main() {
  late Harness h;
  late AccountsRepository accounts;

  setUp(() async {
    h = await Harness.create()
      ..providerFor(_id);
    accounts = getIt<AccountsRepository>();
  });

  test('the consent creates the Account microsoft:<address>, its tokens only in the keychain', () async {
    final r = await accounts.connectMicrosoft();

    expect(r, isA<Ok<Account>>());
    final account = (r as Ok<Account>).value;
    expect((account.id, account.address, account.provider), (_id, 'ada@outlook.com', ProviderKind.microsoft));
    expect(account.status, AccountStatus.attivo);
    expect(h.keychain.values.keys, ['oauth:$_id']);
    expect(h.keychain.values['oauth:$_id'], allOf(contains('ms-access-token-1'), contains('ms-refresh-token-1')));

    final db = getIt<PostinoDatabase>();
    final tables = await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'table'").get();
    final stored = [
      for (final t in tables)
        for (final row in await db.customSelect('SELECT * FROM "${t.read<String>('name')}"').get()) ...row.data.values,
    ].join('|');
    expect(stored, contains('ada@outlook.com'), reason: 'the Account is there');
    expect(stored, isNot(contains('token')));
    final log = await h.errorLog.read();
    expect(log, isNot(contains('ms-access-token')), reason: 'nor in the log of errors');
    expect(log, isNot(contains('ms-refresh-token')));
  });

  test('every failure of the consent writes nothing', () async {
    for (final failure in <Failure>[
      const CancelledFailure(),
      const WorkAccountFailure(),
      const MissingPermissionFailure(),
      const ConfigurationFailure('MICROSOFT_CLIENT_ID'),
      const OfflineFailure(),
    ]) {
      h.microsoft.failure = failure;
      expect(_failure(await accounts.connectMicrosoft()), same(failure));
    }
    expect(h.keychain.values, isEmpty);
    expect(await getIt<MailStore>().accounts(), isEmpty);
  });

  test('the address in any case is the same Account', () async {
    h.microsoft.address = 'Ada@Outlook.com';
    await accounts.connectMicrosoft();

    expect((await getIt<MailStore>().accounts()).map((a) => a.id), [_id]);
  });

  test('an address already connected with another Provider is another Account beside it (ADR 0016)', () async {
    await getIt<MailStore>().addAccount(
      const Account(
        id: 'imap:ada@outlook.com',
        address: 'ada@outlook.com',
        provider: ProviderKind.imap,
        color: 0,
        position: 0,
      ),
    );

    final r = await accounts.connectMicrosoft();

    expect((r as Ok<Account>).value.id, _id);
    expect((await getIt<MailStore>().accounts()).map((a) => a.id), ['imap:ada@outlook.com', _id]);
  });

  test('reconnecting with another identity is WrongAccount, nothing written', () async {
    await accounts.connectMicrosoft();
    final before = Map.of(h.keychain.values);

    h.microsoft.address = 'bob@outlook.com';
    final r = await accounts.connectMicrosoft(loginHint: 'ada@outlook.com');

    expect(_failure(r), isA<WrongAccountFailure>().having((f) => f.expected, 'expected', 'ada@outlook.com'));
    expect(h.keychain.values, before);
    expect((await getIt<MailStore>().accounts()).map((a) => a.id), [_id]);
  });

  test('reconnecting a Da ricollegare Account brings it back to attivo with the hint', () async {
    final store = getIt<MailStore>();
    await accounts.connectMicrosoft();
    await store.setStatus(_id, AccountStatus.daRicollegare);
    h.keychain.values.clear();

    final r = await accounts.connectMicrosoft(loginHint: 'ada@outlook.com');

    expect(r, isA<Ok<Account>>());
    expect(h.microsoft.lastLoginHint, 'ada@outlook.com');
    expect((await store.accounts()).single.status, AccountStatus.attivo);
    expect(h.keychain.values.keys, ['oauth:$_id']);
  });

  test('a Microsoft Account is removed without sending its token to Google', () async {
    await accounts.connectMicrosoft();

    await accounts.remove(_id);

    expect(h.httpRequests, isEmpty);
    expect(await getIt<MailStore>().accounts(), isEmpty);
    expect(h.keychain.values, isEmpty);
  });

  test('an Outlook.com address in the password form points to «Collega Outlook», nothing written', () async {
    for (final address in [
      'ada@outlook.com',
      'ada@outlook.it',
      'ada@hotmail.com',
      'ada@hotmail.it',
      'ada@live.com',
      'ada@live.it',
      'ada@msn.com',
      ' Ada@Outlook.COM ',
    ]) {
      expect(_failure(await accounts.connectWithPassword(address, 'x')), isA<UseMicrosoftFailure>(), reason: address);
    }
    expect(h.keychain.values, isEmpty);
    expect(await getIt<MailStore>().accounts(), isEmpty);
  });

  test(
    'an IMAP Account saved on an Outlook.com address before the button still reconnects with its password',
    () async {
      await getIt<MailStore>().addAccount(
        const Account(
          id: 'imap:ada@outlook.com',
          address: 'ada@outlook.com',
          provider: ProviderKind.imap,
          color: 0,
          position: 0,
        ),
      );
      h.discovery.servers['ada@outlook.com'] = const ServerSettings(
        imap: MailServer(host: 'imap.example.org', port: 993, security: ServerSecurity.ssl),
        smtp: MailServer(host: 'smtp.example.org', port: 465, security: ServerSecurity.ssl),
      );
      await getIt<MailStore>().setStatus('imap:ada@outlook.com', AccountStatus.daRicollegare);

      final r = await accounts.connectWithPassword('ada@outlook.com', 'app-password-1');

      expect(r, isA<Ok<Account>>());
      expect((await getIt<MailStore>().accounts()).single.status, AccountStatus.attivo);
    },
  );
}
