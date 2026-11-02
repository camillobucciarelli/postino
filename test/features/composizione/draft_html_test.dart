// Editor <-> HTML of a Bozza (#35): the seven formats survive the round trip, everything else flattens to text.
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/features/composizione/domain/draft_html.dart';

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

    test(
      'the HTML of Gmail and Mail with <div> and <br> keeps its line breaks',
      () {
        expect(
          _normal(
            htmlToDelta('<div>Prima riga<br>Seconda</div><div>Terza</div>'),
          ),
          [
            {'insert': 'Prima riga\nSeconda\nTerza\n'},
          ],
        );
      },
    );

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

    test('empty HTML is the empty document', () {
      expect(htmlToDelta(''), [
        {'insert': '\n'},
      ]);
    });
  });
}
