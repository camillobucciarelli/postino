// Contract suite of the search on the Provider (#207): every adapter passes the same cases.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/provider_search_page.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/search_query.dart';

import '../../support/fake_mail_provider.dart';
import 'mail_provider_contract.dart';

/// a: an old (older than the sync window), read invoice from Ada; b: a recent, unread meeting with a Stella from
/// Carla, Dario in Cc; s: an invoice in Spam.
Future<void> _mailbox(ContractHarness h) async {
  await h.deliver(
    msg(
      'a',
      subject: 'Fattura di marzo',
      fromName: 'Ada Rossi',
      to: ['bruno@example.com'],
      snippet: 'Il totale da pagare',
      isRead: true,
      date: DateTime.utc(2025, 3, 10, 9),
    ),
  );
  await h.deliver(
    msg(
      'b',
      subject: 'Riunione',
      from: 'carla@example.com',
      cc: ['dario@example.com'],
      snippet: 'Ordine del giorno',
      isStarred: true,
      date: DateTime.utc(2026, 10, 20, 9),
    ),
  );
  await h.deliver(msg('s', subject: 'Fattura sospetta', labelIds: const [spamLabelId], date: DateTime.utc(2026, 10)));
}

void mailProviderSearchContract(String name, CreateHarness create) {
  group('MailProvider search contract: $name', () {
    late ContractHarness h;
    setUp(() async => h = await create());
    tearDown(() => h.dispose());

    Future<ProviderSearchPage> page(SearchQuery q, {String? token, Set<String> stored = const {}}) async =>
        switch (await h.provider.search(q, pageToken: token, stored: stored)) {
          Ok(:final value) => value,
          Err(:final failure) => fail('expected Ok, got $failure'),
        };

    /// The keys (`msg(key)`) of the messages found, by Message-ID.
    Future<Set<String>> found(SearchQuery q) async => {
      for (final m in (await page(q)).messages) m.messageId.substring(1, m.messageId.indexOf('@')),
    };

    test('each field finds its message, old ones too; never in Spam', () async {
      await _mailbox(h);
      expect(await found(const SearchQuery(terms: ['fattura'])), {'a'});
      expect(await found(const SearchQuery(phrase: 'totale da pagare')), {'a'});
      expect(await found(const SearchQuery(from: 'carla')), {'b'});
      expect(await found(const SearchQuery(from: 'Rossi')), {'a'}, reason: 'the sender name');
      expect(await found(const SearchQuery(to: 'dario')), {'b'}, reason: 'Cc counts as a recipient');
      expect(await found(const SearchQuery(subject: 'riunione')), {'b'});
      expect(await found(SearchQuery(from: 'example', after: DateTime(2026, 10))), {'b'});
      expect(await found(SearchQuery(from: 'example', before: DateTime(2025, 12, 31))), {'a'});
      expect(await found(const SearchQuery(from: 'example', unread: true)), {'b'});
      expect(await found(const SearchQuery(from: 'example', starred: true)), {'b'});
      expect(await found(const SearchQuery(from: 'example')), {'a', 'b'});
      await h.attach(h.idOf('a'), 'fattura.pdf', [1, 2, 3]);
      expect(await found(const SearchQuery(from: 'example', hasAttachment: true)), {'a'});
    });

    test('a result comes with its Conversazione and Etichette, like the sync', () async {
      await _mailbox(h);
      final p = await page(const SearchQuery(terms: ['riunione']));
      final m = p.messages.single;
      expect(m.conversationId, h.conversationOf('b'));
      expect(m.labelIds, contains(inboxLabelId));
      expect(m.isStarred, isTrue);
      expect(p.conversationIds, {h.conversationOf('b')});
    });

    test('a message already stored here is not fetched again: only its Conversazione is in the page', () async {
      await _mailbox(h);
      final p = await page(const SearchQuery(terms: ['fattura']), stored: {h.idOf('a')});
      expect(p.messages, isEmpty);
      expect(p.conversationIds, {h.conversationOf('a')});
    });

    test('the pages follow one another to the last, each match once', () async {
      for (var i = 0; i < 5; i++) {
        await h.deliver(msg('p$i', subject: 'Preventivo $i', date: DateTime.utc(2026, 10, 1 + i)));
      }
      final ids = <String>[];
      String? token;
      var pages = 0;
      do {
        final p = await page(const SearchQuery(terms: ['preventivo']), token: token);
        ids.addAll(p.messages.map((m) => m.messageId));
        token = p.nextPageToken;
      } while (token != null && ++pages < 10);
      expect(ids, unorderedEquals([for (var i = 0; i < 5; i++) '<p$i@example.com>']));
    });

    test('nothing found, or nothing to look for: an empty last page', () async {
      await _mailbox(h);
      expect(await page(const SearchQuery(terms: ['inesistente'])), const ProviderSearchPage());
      expect(await page(const SearchQuery()), const ProviderSearchPage());
    });

    test('a refused login is an AuthFailure, no network an OfflineFailure', () async {
      await _mailbox(h);
      await h.breakAuth();
      expect(
        await h.provider.search(const SearchQuery(terms: ['fattura'])),
        isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<AuthFailure>()),
      );
      final offline = await create();
      addTearDown(offline.dispose);
      await offline.goOffline();
      expect(
        await offline.provider.search(const SearchQuery(terms: ['fattura'])),
        isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<OfflineFailure>()),
      );
    });
  });
}
