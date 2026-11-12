// The SearchQuery as `UID SEARCH` criteria (#208): each field, UTF-8, what the user typed never a command.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_search.dart';
import 'package:postino/core/domain/search_query.dart';

void main() {
  test('the finds are filtered on the user\'s local days, which the day-wide SEARCH only brackets', () {
    final q = SearchQuery(after: DateTime(2026, 3), before: DateTime(2026, 3, 31));
    expect(imapInDays(q, DateTime(2026, 2, 28, 23, 59)), isFalse);
    expect(imapInDays(q, DateTime(2026, 3)), isTrue);
    expect(imapInDays(q, DateTime(2026, 3, 31, 23, 59)), isTrue);
    expect(imapInDays(q, DateTime(2026, 4)), isFalse);
    expect(imapInDays(const SearchQuery(terms: ['x']), DateTime(2000)), isTrue);
  });

  const prefix = 'CHARSET UTF-8 NOT DELETED';

  test('every field has its key; the words of sender, recipients and subject each on their own', () {
    final criteria = imapSearchCriteria(
      SearchQuery(
        terms: const ['fattura marzo', 'totale'],
        phrase: 'da pagare',
        from: 'ada rossi',
        to: 'dario',
        subject: 'riunione',
        after: DateTime(2026, 3, 1, 17),
        before: DateTime(2026, 3, 31),
        unread: true,
        starred: true,
        hasAttachment: true,
      ),
    );
    expect(
      criteria,
      '$prefix TEXT "fattura" TEXT "marzo" TEXT "totale" TEXT "da pagare" '
      'OR FROM "ada" HEADER From "ada" OR FROM "rossi" HEADER From "rossi" '
      'OR TO "dario" OR CC "dario" OR HEADER To "dario" HEADER Cc "dario" '
      'SUBJECT "riunione" SENTSINCE 28-Feb-2026 SENTBEFORE 2-Apr-2026 UNSEEN FLAGGED '
      'HEADER Content-Type "multipart/mixed"',
    );
  });

  test('dates are whole days: the day after for BEFORE, across the month end', () {
    expect(imapSearchCriteria(SearchQuery(before: DateTime(2026, 12, 31, 23, 59))), '$prefix SENTBEFORE 2-Jan-2027');
  });

  test('quotes and backslashes are escaped: the text cannot close the string or add a key', () {
    expect(imapSearchCriteria(const SearchQuery(terms: [r'a"b\c'])), '$prefix TEXT "a\\"b\\\\c"');
    expect(
      imapSearchCriteria(const SearchQuery(subject: 'x" ALL "')),
      '$prefix SUBJECT "x\\"" SUBJECT "ALL" SUBJECT "\\""',
    );
    expect(imapSearchCriteria(const SearchQuery(phrase: 'ok\r\nA1 DELETE INBOX')), '$prefix TEXT "ok A1 DELETE INBOX"');
  });

  test('what is not printable ASCII goes as a literal with its UTF-8 length', () {
    expect(imapSearchCriteria(const SearchQuery(terms: ['perché'])), '$prefix TEXT {7}\nperché');
    expect(imapSearchCriteria(const SearchQuery(from: '会议')), '$prefix OR FROM {6}\n会议 HEADER From {6}\n会议');
    expect(imapSearchCriteria(const SearchQuery(terms: ['😀'])), '$prefix TEXT {4}\n😀');
  });

  test('a page below a UID asks for the UIDs under it', () {
    expect(imapSearchCriteria(const SearchQuery(terms: ['x']), below: 71), '$prefix UID 1:70 TEXT "x"');
  });

  test('nothing to look for, whatever the control characters: null', () {
    expect(imapSearchCriteria(const SearchQuery()), isNull);
    expect(imapSearchCriteria(const SearchQuery(terms: ['', ' \t\n'], phrase: '\x00 ')), isNull);
    expect(imapSearchCriteria(const SearchQuery(unread: false, accountNames: ['ada'])), isNull);
  });
}
