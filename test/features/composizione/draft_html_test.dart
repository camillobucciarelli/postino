// HTML fixtures split across lines: the tags are the separators, no whitespace is wanted between fragments.
// ignore_for_file: missing_whitespace_between_adjacent_strings
// Editor <-> HTML of a Bozza (#35): the seven formats survive the round trip, everything else flattens to text.
import 'package:flutter_quill/flutter_quill.dart' show Document;
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/reply.dart';
import 'package:postino/features/composizione/domain/draft_html.dart';

import '../../support/fake_mail_provider.dart';

/// Adjacent runs with the same attributes as one, as a quill Document keeps them.
List<Map<String, dynamic>> _normal(List<Map<String, dynamic>> ops) {
  final d = Delta();
  Delta.fromJson(ops).toList().forEach(d.push);
  return d.toJson();
}

void main() {
  group('deltaToHtml -> htmlToDelta', () {
    test('a document with all seven formats comes back equal', () {
      final ops = <Map<String, dynamic>>[
        {'insert': 'Ciao '},
        {
          'insert': 'grassetto',
          'attributes': {'bold': true},
        },
        {'insert': ' '},
        {
          'insert': 'corsivo',
          'attributes': {'italic': true},
        },
        {'insert': ' '},
        {
          'insert': 'sotto',
          'attributes': {'underline': true},
        },
        {'insert': ' '},
        {
          'insert': 'barrato',
          'attributes': {'strike': true},
        },
        {'insert': ' '},
        {
          'insert': 'link',
          'attributes': {'link': 'https://example.com'},
        },
        {'insert': '\n'},
        {'insert': 'uno'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'due'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
      ];
      expect(_normal(htmlToDelta(deltaToHtml(ops))), _normal(ops));
    });

    test('the HTML of Gmail and Mail with <div> and <br> keeps its line breaks', () {
      expect(_normal(htmlToDelta('<div>Prima riga<br>Seconda</div><div>Terza</div>')), [
        {'insert': 'Prima riga\nSeconda\nTerza\n'},
      ]);
    });

    test('header, image and colour are flattened to text', () {
      expect(
        _normal(
          htmlToDelta(
            '<h1>Titolo</h1><p><span style="color: red">rosso</span>'
            '<img src="https://example.com/a.png"></p>',
          ),
        ),
        [
          {'insert': 'Titolo\nrosso\n'},
        ],
      );
    });

    test('the quote of a reply (#37) keeps its blockquote', () {
      final ops = <Map<String, dynamic>>[
        {'insert': 'ciao'},
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
      ];
      expect(_normal(htmlToDelta('<blockquote><p>ciao</p></blockquote>')), ops);
      expect(deltaToHtml(ops), startsWith('<blockquote'));
      expect(_normal(htmlToDelta(deltaToHtml(ops))), ops);
    });

    test('a blockquote of two paragraphs keeps two quoted lines (#37)', () {
      const bq = {'blockquote': true};
      expect(_normal(htmlToDelta('<blockquote><p>a</p><p>b</p></blockquote>')), [
        {'insert': 'a'},
        {'insert': '\n', 'attributes': bq},
        {'insert': 'b'},
        {'insert': '\n', 'attributes': bq},
      ]);
    });

    test('the Citazione of a reply: attribution as a paragraph, the quoted lines after', () {
      final m = msg('o', fromName: 'Ada', subject: 'Cena');
      final html = quoteHtml(
        m,
        dateLabel: 'lunedì 2 novembre 2026 alle 10:00',
        bodyHtml: '<p>Venerdì?</p><p><strong>Alle 20</strong></p>',
      );
      const bq = {'blockquote': true};
      expect(_normal(htmlToDelta('<p>Prima</p>$html')), [
        {'insert': 'Prima\nIl giorno lunedì 2 novembre 2026 alle 10:00 Ada <ada@example.com> ha scritto:\nVenerdì?'},
        {'insert': '\n', 'attributes': bq},
        {
          'insert': 'Alle 20',
          'attributes': {'bold': true},
        },
        {'insert': '\n', 'attributes': bq},
      ]);
    });

    test('text nodes stay literal: a typed <address> and an escaped tag are not parsed', () {
      expect(
        Document.fromJson(htmlToDelta('<div>Scrivi a &lt;alice@example.com&gt;</div>')).toPlainText(),
        'Scrivi a <alice@example.com>\n',
      );
      final ops = htmlToDelta('<div>&lt;b&gt;no&lt;/b&gt;</div>');
      expect(Document.fromJson(ops).toPlainText(), '<b>no</b>\n');
      expect(ops.any((o) => o['attributes'] != null), isFalse);
    });

    test('the space between two inline elements is kept', () {
      expect(Document.fromJson(htmlToDelta('<div><b>uno</b> <i>due</i></div>')).toPlainText(), 'uno due\n');
    });

    test('empty HTML is the empty document', () {
      expect(htmlToDelta(''), [
        {'insert': '\n'},
      ]);
    });
  });
}
