import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/accounts_repository.dart';
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
}
