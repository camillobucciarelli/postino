import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/search_query_parser.dart';

void main() {
  test('words are free text, in AND', () {
    final q = parseSearchQuery('  fattura   Marzo ');
    expect(q.terms, ['fattura', 'Marzo'], reason: 'case is kept: the index ignores it');
    expect(q.isEmpty, isFalse);
  });

  test('quotes make the exact phrase, closed or not', () {
    expect(parseSearchQuery('"nota spese" ottobre').phrase, 'nota spese');
    expect(parseSearchQuery('"nota spese" ottobre').terms, ['ottobre']);
    expect(parseSearchQuery('"nota spe').phrase, 'nota spe');
  });

  test('only the first phrase is a phrase: the others are free words', () {
    final q = parseSearchQuery('"uno due" "tre quattro"');
    expect(q.phrase, 'uno due');
    expect(q.terms, ['tre', 'quattro']);
  });

  test('operators in Italian and English, whatever the case', () {
    final q = parseSearchQuery('da:anna A:bruno oggetto:fattura');
    expect([q.from, q.to, q.subject], ['anna', 'bruno', 'fattura']);
    expect(q.terms, isEmpty);
    final en = parseSearchQuery('FROM:anna to:bruno Subject:invoice');
    expect((en.from, en.to, en.subject), ('anna', 'bruno', 'invoice'));
  });

  test('an operator takes a quoted value and repeats in AND', () {
    final q = parseSearchQuery('da:"Anna Rossi" da:example oggetto:"nota spese"');
    expect((q.from, q.subject), ('Anna Rossi example', 'nota spese'));
  });

  test('accents are kept as typed', () {
    expect(parseSearchQuery('perché Città').terms, ['perché', 'Città']);
    expect(parseSearchQuery('da:Zoë').from, 'Zoë');
  });

  test('an operator without its value yet is ignored while typing', () {
    final q = parseSearchQuery('fattura da:');
    expect(q.terms, ['fattura']);
    expect(q.from, isNull);
    expect(parseSearchQuery('da:').isEmpty, isTrue);
  });

  test('an unknown name: stays free text', () {
    expect(parseSearchQuery('ora:10 http://x').terms, ['ora:10', 'http://x']);
  });

  test('empty, blank or punctuation-free-of-words input searches nothing', () {
    expect(parseSearchQuery('').isEmpty, isTrue);
    expect(parseSearchQuery('   \t ').isEmpty, isTrue);
    expect(parseSearchQuery('""').isEmpty, isTrue);
  });

  group('criteria (#206)', () {
    test('è: / is: take unread and starred, in both languages and whatever the case', () {
      expect(parseSearchQuery('è:nonletto').unread, isTrue);
      expect(parseSearchQuery('IS:unread').unread, isTrue);
      expect(parseSearchQuery('è:stella').starred, isTrue);
      expect(parseSearchQuery('is:Starred').starred, isTrue);
      expect(parseSearchQuery('è:nonletto').starred, isNull);
    });

    test('ha: / has: takes attachments', () {
      expect(parseSearchQuery('ha:allegato').hasAttachment, isTrue);
      expect(parseSearchQuery('has:attachment').hasAttachment, isTrue);
      expect(parseSearchQuery('HA:Allegati').hasAttachment, isTrue);
    });

    test('a query of criteria alone is not empty, and keeps the free text apart', () {
      final q = parseSearchQuery('è:nonletto ha:allegato fattura');
      expect([q.unread, q.hasAttachment], [true, true]);
      expect(q.terms, ['fattura']);
      expect(parseSearchQuery('è:nonletto').isEmpty, isFalse);
      expect(parseSearchQuery('dopo:2026-01-02').isEmpty, isFalse);
      expect(parseSearchQuery('account:anna').isEmpty, isFalse);
    });

    test('dates are local days, in ISO or Gmail form, both ends included', () {
      final q = parseSearchQuery('dopo:2026-03-01 prima:2026/03/31');
      expect(q.after, DateTime(2026, 3));
      expect(q.before, DateTime(2026, 3, 31));
      final en = parseSearchQuery('after:2026-3-5 before:2026-12-1');
      expect((en.after, en.before), (DateTime(2026, 3, 5), DateTime(2026, 12)));
    });

    test('account: takes names, as alternatives', () {
      expect(parseSearchQuery('account:anna account:"b c"').accountNames, ['anna', 'b c']);
    });

    test('a known operator with a value it cannot read stays free text; with no value yet it is ignored', () {
      for (final bad in ['dopo:ieri', 'prima:2026-02-31', 'dopo:2026-13-05', 'dopo:2026-1', 'è:rosso', 'ha:fame']) {
        final q = parseSearchQuery(bad);
        expect(q.terms, [bad], reason: bad);
        expect((q.after, q.before, q.unread, q.starred, q.hasAttachment), (null, null, null, null, null));
      }
      for (final typing in ['dopo:', 'è:', 'ha:', 'account:']) {
        expect(parseSearchQuery(typing).isEmpty, isTrue, reason: typing);
      }
    });

    test('inAccounts keeps every criterion', () {
      final q = parseSearchQuery('è:nonletto è:stella ha:allegato dopo:2026-01-01 prima:2026-02-01 account:x a');
      final scoped = q.inAccounts({'a1'});
      expect(scoped.accountIds, {'a1'});
      expect(
        scoped.props.where((p) => p is! Set).toList(),
        q.props.where((p) => p is! Set).toList(),
        reason: 'only the Accounts differ',
      );
    });
  });
}
