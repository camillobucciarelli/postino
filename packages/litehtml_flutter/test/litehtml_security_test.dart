// HTML non fidato (#383): annidamento e dimensione oltre i limiti danno un rendering degradato o una
// LitehtmlException, mai un crash. Un crash nativo qui fa cadere l'intero processo di test.
import 'package:flutter_test/flutter_test.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';
import 'package:litehtml_flutter/src/bindings.dart' show lhMaxHtmlBytes;

const _levels = 100000;

/// Crea, impagina e disegna [html]; restituisce l'altezza.
double render(String html) {
  final doc = LitehtmlDocument(html, 600);
  try {
    final height = doc.layout(600);
    doc.record().dispose();
    return height;
  } finally {
    doc.dispose();
  }
}

Matcher throwsLitehtml(LitehtmlFailure failure) =>
    throwsA(isA<LitehtmlException>().having((e) => e.failure, 'failure', failure));

void main() {
  group('CSS annidato a $_levels livelli: blocco troncato, il resto si applica', () {
    const after = '<div style="height: 10px"></div>';

    test('parentesi in un foglio di stile', () {
      expect(render('<body style="margin: 0"><style>a { color: ${'(' * _levels} }</style>$after'), 10);
    });

    test('blocchi graffa in un foglio di stile', () {
      expect(render('<body style="margin: 0"><style>${'a{' * _levels}</style>$after'), 10);
    });

    test('@media annidate', () {
      expect(render('<body style="margin: 0"><style>${'@media screen{' * _levels}</style>$after'), 10);
    });

    test('funzioni in uno style inline', () {
      expect(render('<body style="margin: 0"><p style="color: ${'f(' * _levels}">x</p>$after'), greaterThan(10));
    });

    test('selettori :not annidati', () {
      expect(render('<body style="margin: 0"><style>${':not(' * _levels}a{color:red}</style>$after'), 10);
    });

    test('regola dopo un blocco troppo annidato chiuso bene', () {
      final deep = '${'[' * 40}${']' * 40}';
      expect(
        render('<body style="margin: 0"><style>b { x: $deep } .h { height: 7px }</style><div class="h"></div>'),
        7,
      );
    });
  });

  group('HTML annidato', () {
    test('$_levels <div> → tooDeep, non un crash', () {
      expect(() => render('${'<div>' * _levels}x'), throwsLitehtml(LitehtmlFailure.tooDeep));
    });

    test('$_levels tag diversi → tooDeep', () {
      expect(() => render('${'<div><span><b><i><ul><li>' * (_levels ~/ 6)}x'), throwsLitehtml(LitehtmlFailure.tooDeep));
    });

    test('500 <div> (oltre il tetto del DOM, sotto quello del parser): nodi appiattiti e resi', () {
      // Appiattito, il div alto 10 perde il suo testo, che diventa una riga a parte dopo di lui.
      expect(render('<body style="margin: 0">${'<div>' * 500}<div style="height: 10px">x</div>'), greaterThan(10));
    });

    test('tabelle annidate: budget di layout → layout, non un blocco infinito', () {
      final doc = LitehtmlDocument('${'<table><tr><td>' * 40}x', 600);
      addTearDown(doc.dispose);

      expect(() => doc.layout(600), throwsLitehtml(LitehtmlFailure.layout));
      // Dopo il fallimento il documento resta inutilizzabile, senza crash.
      expect(() => doc.layout(600), throwsLitehtml(LitehtmlFailure.layout));
      doc.record().dispose();
    });
  });

  group('dimensione', () {
    test('oltre il limite in unità UTF-16 → tooLarge senza copiare', () {
      expect(() => LitehtmlDocument('x' * (lhMaxHtmlBytes + 1), 600), throwsLitehtml(LitehtmlFailure.tooLarge));
    });

    test('oltre il limite in byte UTF-8 → tooLarge dal motore', () {
      // 'è' è un'unità UTF-16 e due byte UTF-8: supera il limite solo in byte.
      final html = 'è' * (lhMaxHtmlBytes ~/ 2 + 1);
      expect(html.length, lessThan(lhMaxHtmlBytes));
      expect(() => LitehtmlDocument(html, 600), throwsLitehtml(LitehtmlFailure.tooLarge));
    });
  });

  group('tabelle', () {
    test('colspan e rowspan zero, negativi o enormi', () {
      const html =
          '<table><tr><td colspan="0">a</td><td colspan="-5">b</td></tr> '
          '<tr><td rowspan="-3">c</td><td rowspan="99999999999">d</td></tr></table>';
      expect(render(html), greaterThan(0));
    });

    test('colspan enorme in molte celle → failed (budget di celle)', () {
      expect(() => render('<table><tr>${'<td colspan="1000">x' * 1000}'), throwsLitehtml(LitehtmlFailure.failed));
    });
  });
}
