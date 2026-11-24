// ignore_for_file: missing_whitespace_between_adjacent_strings
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';

LitehtmlContent contentOf(String html, [double width = 400]) {
  final doc = LitehtmlDocument(html, width);
  addTearDown(doc.dispose);
  doc.layout(width);
  return doc.content();
}

void main() {
  group('testo copiato', () {
    test('<br> e paragrafi vanno a capo, le righe spezzate dal layout restano unite da uno spazio', () {
      expect(contentOf('<p>uno<br>due</p><p>tre <b>quattro</b></p>').plainText, 'uno\ndue\ntre quattro');
      expect(contentOf('<p style="width: 60px">uno due tre quattro</p>').plainText, 'uno due tre quattro');
    });

    test('gli a capo espliciti di fila si contano (riga vuota), i confini di blocco no', () {
      expect(contentOf('<p>uno<br><br>due</p>').plainText, 'uno\n\ndue');
      expect(contentOf('<pre>uno\n\ndue</pre>').plainText, 'uno\n\ndue');
      expect(contentOf('<div><div><p>uno</p></div></div><div><p>due</p></div>').plainText, 'uno\ndue');
    });

    test('ogni cella di tabella va a capo, in ordine di documento', () {
      const html = '<table><tr><td>a</td><td>b b</td></tr><tr><td>c</td></tr></table>';
      expect(contentOf(html).plainText, 'a\nb b\nc');
    });

    test('testo trasformato e <pre> come disegnati; display:none escluso', () {
      const html = '<p style="text-transform: uppercase">ciao</p><pre>a  b\nc</pre><div style="display: none">no</div>';
      expect(contentOf(html).plainText, 'CIAO\na  b\nc');
    });

    test('il testo tagliato da overflow non si copia né si annuncia (preheader)', () {
      final content = contentOf(
        '<div style="max-height: 0; overflow: hidden">nascosto <a href="https://x.it">link</a></div> '
        '<p>visibile</p>',
      );
      expect(content.plainText, 'visibile');
      expect(content.nodes.map((n) => n.label), ['visibile']);
    });

    test('i frammenti hanno il box del testo disegnato', () {
      final f = contentOf('<body style="margin: 0"><p style="margin: 0; font-size: 20px">ciao</p>').fragments.single;
      expect(f.offset, Offset.zero);
      expect(f.height, greaterThan(19));
      expect(f.style.fontSize, 20);
    });
  });

  group('nodi', () {
    test('titoli con livello, paragrafi spezzati attorno ai link', () {
      final nodes = contentOf('<h2>Titolo</h2><p>Vai <a href="https://x.it/a">al sito</a> ora</p>').nodes;
      expect(nodes.map((n) => n.label), ['Titolo', 'Vai', 'al sito', 'ora']);
      expect(nodes.map((n) => n.headingLevel), [2, 0, 0, 0]);
      expect(nodes.map((n) => n.href), [null, null, 'https://x.it/a', null]);
    });

    test('immagini: alt come etichetta, alt vuoto decorativa, in un link danno il nome al link', () {
      final nodes = contentOf(
        '<img alt="Foto" width="10" height="10"><img alt="" width="10" height="10"> '
        '<a href="https://e.com"><img alt="Logo" width="10" height="10"></a> '
        '<a href="https://vuoto.it/p"><img width="10" height="10"></a>',
      ).nodes;
      expect(nodes.map((n) => (n.label, n.image, n.href)), [
        ('Foto', true, null),
        ('Logo', false, 'https://e.com'),
        // Senza testo né alt: il dominio.
        ('vuoto.it', false, 'https://vuoto.it/p'),
      ]);
    });

    test('un link con <br> resta un solo nodo', () {
      final links = contentOf('<p><a href="https://x.it">uno<br>due</a></p>').links;
      expect(links.map((l) => l.label), ['uno due']);
      expect(links.single.rects, hasLength(2));
    });

    test('un link su due righe ha un box per riga', () {
      final link = contentOf('<p style="width: 80px"><a href="https://x.it">uno due tre</a></p>').links.single;
      expect(link.rects, hasLength(greaterThan(1)));
    });
  });

  group('area dei link', () {
    test('un\'ancora a blocco o inline-block copre tutto il suo box, una inline solo il testo', () {
      final links = contentOf(
        '<body style="margin: 0; font-size: 10px">'
        '<a href="b" style="display: block; height: 40px">blocco</a>'
        '<a href="i" style="display: inline-block; padding: 20px">bottone</a> '
        '<a href="t">testo</a>',
      ).links.toList();
      expect(links.map((l) => l.href), ['b', 'i', 't']);
      expect(links[0].rects.single, const Rect.fromLTWH(0, 0, 400, 40));
      expect(links[1].rects.single.height, greaterThanOrEqualTo(50));
      expect(links[2].rects.single.height, lessThan(20));
    });
  });
}
