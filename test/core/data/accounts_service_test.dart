import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/accounts_repository.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/main.dart';

import '../../support/harness.dart';

void main() {
  test('tokens go only to the keychain, never to the database', () async {
    final h = await Harness.create();
    h.providerFor('gmail:ada@gmail.com');

    await getIt<AccountsRepository>().connectGmail();

    final kept = h.keychain.values.values.join();
    expect(kept, contains('access-token-1'));
    expect(kept, contains('refresh-token-1'));

    final db = getIt<PostinoDatabase>();
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final stored = [
      for (final t in tables)
        for (final row
            in await db
                .customSelect('SELECT * FROM "${t.read<String>('name')}"')
                .get())
          ...row.data.values,
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
    expect(
      (r as Err).failure,
      isA<WrongAccountFailure>().having(
        (f) => f.expected,
        'expected',
        'Ada@Gmail.com',
      ),
    );
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

  test(
    'reconnecting with the grant in another case keeps the same Account',
    () async {
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
    },
  );

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
