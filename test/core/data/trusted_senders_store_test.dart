// Mittenti fidati (#47): the exact address, normalized, in their own drift table.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/trusted_senders_store.dart';
import 'package:postino/core/domain/trusted_senders_repository.dart';

void main() {
  test('normalizeAddress: the exact address, trimmed and lowercase', () {
    expect(normalizeAddress('  Ada@Example.COM '), 'ada@example.com');
    expect(normalizeAddress('Ada Lovelace <Ada@Example.com>'), 'ada@example.com');
    expect(normalizeAddress('"Lovelace, Ada" < ada@example.com >'), 'ada@example.com');
  });

  late PostinoDatabase db;
  late TrustedSendersStore store;
  setUp(() {
    db = PostinoDatabase.inMemory();
    store = TrustedSendersStore(db);
  });
  tearDown(() => db.close());

  test('trust saves the normalized address in trusted_senders, once', () async {
    await store.trust(' Ada <ADA@example.com>');
    await store.trust('ada@example.com');

    final rows = await db.select(db.trustedSenders).get();
    expect([for (final r in rows) r.address], ['ada@example.com']);
    expect(await store.watchTrusted().first, {'ada@example.com'});
  });

  test('a message shown once is that message only, in memory', () {
    store.showOnce('a1', 'm1');
    expect(store.shownOnce('a1', 'm1'), isTrue);
    expect(store.shownOnce('a1', 'm2'), isFalse);
    expect(store.shownOnce('a2', 'm1'), isFalse);
  });
}
