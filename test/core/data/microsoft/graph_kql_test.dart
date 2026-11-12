// The translation of a SearchQuery into Graph's `$search` (KQL) and what is filtered here (#209).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/microsoft/graph_kql.dart';
import 'package:postino/core/domain/search_query.dart';

import '../../../support/fake_mail_provider.dart' show msg;

void main() {
  group('graphKql', () {
    test('each field, every value a phrase in escaped quotes, AND between them, one pair of quotes outside', () {
      expect(graphKql(const SearchQuery(terms: ['fattura', 'marzo'])), r'"\"fattura\" AND \"marzo\""');
      expect(graphKql(const SearchQuery(phrase: 'totale  da pagare')), r'"\"totale da pagare\""');
      expect(graphKql(const SearchQuery(from: 'Ada Rossi')), r'"from:\"Ada\" AND from:\"Rossi\""');
      expect(graphKql(const SearchQuery(to: 'dario')), r'"(to:\"dario\" OR cc:\"dario\")"');
      expect(graphKql(const SearchQuery(subject: 'riunione')), r'"subject:\"riunione\""');
      expect(graphKql(const SearchQuery(terms: ['x'], hasAttachment: true)), r'"\"x\" AND hasAttachments:true"');
    });

    test('a quote or a backslash in the text cannot end the phrase: it is a space', () {
      expect(graphKql(const SearchQuery(phrase: r'il "totale\ da')), r'"\"il totale da\""');
      expect(graphKql(const SearchQuery(subject: r'a"b\c')), r'"subject:\"a\" AND subject:\"b\" AND subject:\"c\""');
      expect(graphKql(const SearchQuery(terms: ['"'])), '', reason: 'nothing left to look for');
    });

    test('an operator typed as text stays text', () {
      expect(graphKql(const SearchQuery(terms: ['OR', 'from:ada'])), r'"\"OR\" AND \"from:ada\""');
    });

    test('the days widened by one each side, as KQL reads them in UTC', () {
      expect(
        graphKql(SearchQuery(terms: const ['x'], after: DateTime(2026, 3), before: DateTime(2026, 3, 31))),
        r'"\"x\" AND received>=2026-02-28 AND received<=2026-04-01"',
      );
    });

    test('only unread or Stella: nothing Graph can look for', () {
      expect(graphKql(const SearchQuery(unread: true, starred: true)), '');
      expect(graphKql(const SearchQuery()), '');
    });
  });

  group('graphSearchKeeps', () {
    final read = msg('r', isRead: true, date: DateTime(2026, 3, 1, 0, 30));
    final unread = msg('u', isStarred: true, date: DateTime(2026, 2, 28, 23, 30));

    test('unread and Stella here, per message', () {
      expect(graphSearchKeeps(const SearchQuery(unread: true), read), isFalse);
      expect(graphSearchKeeps(const SearchQuery(unread: true), unread), isTrue);
      expect(graphSearchKeeps(const SearchQuery(starred: true), read), isFalse);
      expect(graphSearchKeeps(const SearchQuery(starred: true), unread), isTrue);
    });

    test('the days by the local day, its edges included', () {
      expect(graphSearchKeeps(SearchQuery(after: DateTime(2026, 3)), read), isTrue);
      expect(graphSearchKeeps(SearchQuery(after: DateTime(2026, 3)), unread), isFalse);
      expect(graphSearchKeeps(SearchQuery(before: DateTime(2026, 2, 28)), unread), isTrue);
      expect(graphSearchKeeps(SearchQuery(before: DateTime(2026, 2, 28)), read), isFalse);
    });
  });
}
