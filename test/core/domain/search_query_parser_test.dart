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
}
