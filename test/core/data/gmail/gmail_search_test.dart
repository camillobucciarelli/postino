// The translation of a SearchQuery into Gmail's `q` (#207).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/gmail/gmail_search.dart';
import 'package:postino/core/domain/search_query.dart';

int _epoch(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

void main() {
  test('every field has its operator, each value quoted', () {
    expect(gmailQuery(const SearchQuery(terms: ['fattura', 'marzo'])), '"fattura" "marzo"');
    expect(gmailQuery(const SearchQuery(phrase: 'totale da pagare')), '"totale da pagare"');
    expect(gmailQuery(const SearchQuery(from: 'Ada Rossi')), 'from:"Ada" from:"Rossi"');
    expect(gmailQuery(const SearchQuery(to: 'dario')), '{to:"dario" cc:"dario"}');
    expect(gmailQuery(const SearchQuery(subject: 'riunione')), 'subject:"riunione"');
    expect(
      gmailQuery(const SearchQuery(unread: true, starred: true, hasAttachment: true)),
      'is:unread is:starred has:attachment',
    );
    expect(gmailQuery(const SearchQuery(unread: false, starred: false, hasAttachment: false)), '');
    expect(gmailQuery(const SearchQuery()), '');
  });

  test("what the user types is never an operator: quotes go, operators stay inside the quotes", () {
    expect(gmailQuery(const SearchQuery(terms: ['in:spam', '-ada', 'OR', 'a"b'])), '"in:spam" "-ada" "OR" "a" "b"');
    expect(gmailQuery(const SearchQuery(terms: ['"'])), '', reason: 'nothing left to look for');
    expect(gmailQuery(const SearchQuery(phrase: 'disse "ciao" {x}')), '"disse ciao {x}"');
  });

  test('the dates are epoch seconds at the edges of the local day, never a date Gmail reads in PST', () {
    final q = gmailQuery(SearchQuery(after: DateTime(2026, 3, 1, 15, 30), before: DateTime(2026, 3, 31, 8)));
    expect(q, 'after:${_epoch(DateTime(2026, 3))} before:${_epoch(DateTime(2026, 4))}');
    expect(q, isNot(contains('/')));
  });

  test('a day given in UTC is that calendar day', () {
    expect(gmailQuery(SearchQuery(after: DateTime.utc(2026, 12, 31))), 'after:${_epoch(DateTime(2026, 12, 31))}');
    expect(gmailQuery(SearchQuery(before: DateTime.utc(2026, 12, 31))), 'before:${_epoch(DateTime(2027))}');
  });
}
