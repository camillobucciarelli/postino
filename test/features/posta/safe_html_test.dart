// HTML fixtures split across lines: the tags are the separators, no whitespace is wanted between fragments.
// ignore_for_file: missing_whitespace_between_adjacent_strings
// Cleaning and remote blocking of HTML bodies (#47, ADR 0007).

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:postino/features/posta/domain/safe_html.dart';

SafeHtml _blocked(String html) => prepareHtml(html, allowRemote: false);

void main() {
  group('cleaning', () {
    for (final tag in [
      '<script>alert(1)</script>',
      '<iframe src="data:text/html,x"></iframe>',
      '<object data="x.swf"></object>',
      '<embed src="data:x">',
      '<input value="x">',
      '<button>Invia</button>',
      '<select><option>Uno</option></select>',
      '<textarea>testo</textarea>',
    ]) {
      test('drops $tag', () {
        final out = _blocked('<p>Ciao</p>$tag').html;
        final name = RegExp(r'<(\w+)').firstMatch(tag)![1]!;
        expect(out, isNot(contains('<$name')));
        expect(out, contains('Ciao'));
      });
    }

    test('drops a form but keeps what it says', () {
      final out = _blocked('<form action="https://evil.example/x"><p>Testo</p><input></form>').html;
      expect(out, isNot(contains('<form')));
      expect(out, isNot(contains('evil')));
      expect(out, contains('<p>Testo</p>'));
    });

    test('drops on* attributes', () {
      final out = _blocked('<p onclick="x()" ONMOUSEOVER="y()" class="c">Ciao</p>').html;
      expect(out.toLowerCase(), isNot(contains('on')));
      expect(out, contains('class="c"'));
    });

    test('drops javascript: URLs, however they are spelled', () {
      final out = _blocked(
        '<a href="javascript:alert(1)">a</a><a href=" JaVa\nScRiPt:x">b</a>'
        '<a href="https://example.com">c</a>',
      ).html;
      expect(out.toLowerCase(), isNot(contains('script')));
      expect(out, contains('href="https://example.com"'));
    });
  });

  group('blocking', () {
    test('img src, http and https and protocol-relative', () {
      for (final src in ['http://t.example/p.gif', 'https://t.example/p.gif', '//t.example/p.gif']) {
        final r = _blocked('<img src="$src" alt="Logo">');
        expect(r.blocked, isTrue, reason: src);
        expect(r.html, isNot(contains('t.example')));
        expect(r.html, contains('alt="Logo"'));
      }
    });

    test('srcset', () {
      final r = _blocked('<img srcset="https://t.example/a.png 1x">');
      expect(r.blocked, isTrue);
      expect(r.html, isNot(contains('t.example')));
    });

    test('url(...) in a style attribute and the background attribute', () {
      final r = _blocked(
        '<table><tr><td style="background: url(\'https://t.example/bg.png\')" '
        'background="https://t.example/bg2.png">x</td></tr></table>',
      );
      expect(r.blocked, isTrue);
      expect(r.html, isNot(contains('t.example')));
    });

    test('url(...), @import and remote fonts in <style>', () {
      final r = _blocked('''
<style>
@import url("https://t.example/a.css");
@font-face { font-family: X; src: url(https://t.example/x.woff2); }
body { background-image: url(//t.example/bg.png); }
</style><p>Ciao</p>''');
      expect(r.blocked, isTrue);
      expect(r.html, isNot(contains('t.example')));
      expect(r.html, contains('font-family: X'));
    });

    test('<link rel=stylesheet>', () {
      final r = _blocked('<link rel="stylesheet" href="https://t.example/a.css"><p>x</p>');
      expect(r.blocked, isFalse);
      expect(r.html, isNot(contains('<link')));
    });

    test('data: passes, and blocks nothing', () {
      const png = 'data:image/png;base64,iVBORw0KGgo=';
      final r = _blocked('<img src="$png"><p style="background: url($png)">x</p>');
      expect(r.blocked, isFalse);
      expect(RegExp('data:image').allMatches(r.html), hasLength(2));
    });

    test('cid: loses its src (a placeholder), and blocks nothing', () {
      final r = _blocked('<img src="cid:logo@x" alt="Logo">');
      expect(r.blocked, isFalse);
      expect(r.html, isNot(contains('cid:')));
      expect(r.html, contains('<img alt="Logo">'));
    });

    test('a body without remote resources blocks nothing', () {
      expect(_blocked('<p><a href="https://x.example">link</a></p>').blocked, isFalse);
    });

    test('allowed, remote resources stay but cleaning still runs', () {
      final r = prepareHtml(
        '<img src="https://t.example/a.png" onload="x()"><script>x()</script>'
        '<img src="cid:a">',
        allowRemote: true,
      );
      expect(r.blocked, isFalse);
      expect(r.html, contains('src="https://t.example/a.png"'));
      expect(r.html, isNot(contains('onload')));
      expect(r.html, isNot(contains('<script')));
      expect(r.html, isNot(contains('cid:')));
    });
  });

  test('width: the widest fixed width asked for, max-width aside', () {
    expect(_blocked('<p>x</p>').width, isNull);
    expect(
      _blocked(
        '<table width="600"><tr><td style="width: 640px; max-width: 900px">'
        '<img width="300px"></td></tr></table><div width="100%"></div>',
      ).width,
      640,
    );
  });

  group('table widths (fwfh sizes them badly)', () {
    String style(String html, String tag) => parse(_blocked(html).html).querySelector(tag)!.attributes['style']!;

    test('td and th lose width, min-width, max-width, keep the rest', () {
      for (final tag in ['td', 'th']) {
        expect(
          style(
            '<table><tr><$tag style="color:red;width:24px;min-width: 1px;'
            'MAX-WIDTH:9px;padding:0">x</$tag></tr></table>',
            tag,
          ),
          'color:red;padding:0',
        );
      }
    });

    test('a multi-column table loses a percentage width, keeps px and the rest', () {
      expect(
        style('<table style="width:100%;background:#eee"><tr><td>x</td><td>y</td></tr></table>', 'table'),
        'background:#eee',
      );
      expect(style('<table style="width: 50% !important"><tr><th>a</th><td>b</td></tr></table>', 'table'), '');
      expect(
        style('<table style="width:600px;color:red"><tr><td>a</td><td>b</td></tr></table>', 'table'),
        'width:600px;color:red',
      );
    });

    group('card tables (#63)', () {
      const card =
          '<table width="100%" border="0" style="padding:16px; border:1px solid #F0F1F2; '
          'border-radius:16px;border-collapse:collapse"><tr><td>testo</td></tr></table>';

      test('the box moves to a wrapping div, the table keeps its width', () {
        final div = parse(_blocked(card).html).querySelector('div')!;
        expect(div.attributes['style'], contains('border:1px solid #F0F1F2'));
        expect(div.attributes['style'], contains('padding:16px'));
        expect(div.attributes['style'], contains('border-radius:16px'));
        expect(div.attributes['style'], isNot(contains('collapse')));
        final table = div.querySelector('table')!;
        expect(table.parent, div);
        expect(table.attributes['style'], startsWith('width:100%'));
        expect(table.attributes['style'], contains('border-collapse'));
        expect(table.attributes['style'], isNot(contains('padding')));
        expect(table.attributes['style'], isNot(contains('border:')));
        expect(table.attributes['style'], isNot(contains('radius')));
      });

      test('max-width and margin move to the div with the box', () {
        final div = parse(
          _blocked(
            '<table style="width:100%;max-width:600px;margin:0 auto;border:1px solid red;background:white">'
            '<tr><td>x</td></tr></table>',
          ).html,
        ).querySelector('div')!;
        expect(div.attributes['style'], contains('max-width:600px'));
        expect(div.attributes['style'], contains('margin:0 auto'));
        final t = div.querySelector('table')!.attributes['style'];
        expect(t, isNot(contains('max-width')));
        expect(t, isNot(contains('margin')));
        expect(t, contains('width:100%'));
      });

      test('radius, padding and background alone wrap too', () {
        final div = parse(
          _blocked(
            '<table style="border-radius:8px;padding:4px;background:#eee">'
            '<tr><td>x</td></tr></table>',
          ).html,
        ).querySelector('div')!;
        expect(div.attributes['style'], contains('background:#eee'));
        expect(div.querySelector('table')!.attributes['style'], '');
      });

      for (final t in [
        '<table style="width:600px;border:1px solid red"><tr><td>x</td></tr></table>',
        '<table width="600" style="padding:8px"><tr><td>x</td></tr></table>',
        '<table style="width:50%;padding:8px"><tr><td>x</td></tr></table>',
        '<table style="color:red;border:0;border-collapse:collapse"><tr><td>x</td></tr></table>',
        '<table style="border:none"><tr><td>x</td></tr></table>',
      ]) {
        test('left alone: $t', () {
          expect(parse(_blocked(t).html).querySelector('div'), isNull);
        });
      }
    });

    test('a one-column table keeps its percentage width (#63)', () {
      expect(style('<table style="width:100%;color:red"><tr><td>x</td></tr></table>', 'table'), 'width:100%;color:red');
    });

    test('a one-column table with nested multi-column one keeps its width', () {
      final doc = parse(
        _blocked(
          '<table style="width:100%"><tr><td>'
          '<table style="width:100%"><tr><td>a</td><td>b</td></tr></table>'
          '</td></tr></table>',
        ).html,
      );
      final tables = doc.querySelectorAll('table');
      expect(tables[0].attributes['style'], 'width:100%');
      expect(tables[1].attributes['style'], '');
    });

    test('width="100%" on a one-column table becomes style width (#63)', () {
      expect(style('<table width="100%"><tr><td>x</td></tr></table>', 'table'), startsWith('width:100%'));
      expect(style('<table width="80%" style="color:red"><tr><td>x</td></tr></table>', 'table'), 'width:80%;color:red');
      expect(
        parse(_blocked('<table width="100%"><tr><td>a</td><td>b</td></tr></table>').html)
            .querySelector('table')!
            .attributes
            .containsKey('style'),
        isFalse,
      );
    });

    test('<title> is gone, <style> stays (#63)', () {
      final out = _blocked(
        '<html><head><title>Oggetto</title><meta charset="utf-8">'
        '<style>p{color:red}</style></head><body><p>Ciao</p></body></html>',
      ).html;
      expect(out, isNot(contains('Oggetto')));
      expect(out, contains('p{color:red}'));
    });

    test('contentWidth is measured before stripping', () {
      expect(_blocked('<table><tr><td style="width:640px">x</td></tr></table>').width, 640);
    });
  });

  group('newsletter patches (#67)', () {
    String style(String html, String sel) => parse(_blocked(html).html).querySelector(sel)!.attributes['style'] ?? '';

    test('bgcolor becomes background-color, inline style wins', () {
      expect(
        style('<table bgcolor="#112233"><tr><td>a</td></tr></table>', 'table'),
        startsWith('background-color:#112233;'),
      );
      expect(
        style(
          '<table><tr><td bgcolor="#112233" style="background-color:red">'
              'a</td></tr></table>',
          'td',
        ),
        'background-color:#112233;background-color:red',
      );
    });

    test('bgcolor of a card table moves to the box div', () {
      final doc = parse(
        _blocked(
          '<table width="100%" bgcolor="#112233" '
          'style="border:1px solid red"><tr><td>a</td></tr></table>',
        ).html,
      );
      final div = doc.querySelector('div')!;
      expect(div.attributes['style'], contains('background-color:#112233'));
      expect(doc.querySelector('table')!.attributes['style'], isNot(contains('background')));
    });

    test('td height becomes min-height', () {
      final s = style('<table><tr><td height="16" style="font-size:0">&nbsp;</td></tr></table>', 'td');
      expect(s, contains('min-height:16px'));
      expect(s, isNot(contains(RegExp(r'(^|;)\s*height'))));
    });

    test('an explicit inline min-height wins over the height attribute', () {
      final s = style('<table><tr><td height="16" style="min-height:48px">a</td></tr></table>', 'td');
      expect(s.lastIndexOf('min-height:48px'), greaterThan(s.indexOf('min-height:16px')));
    });

    for (final style in ['display:none', 'display:none!important', 'color:red; DISPLAY : NONE !important']) {
      test('hidden img is removed: $style', () {
        final doc = parse(_blocked('<p>x<img style="$style"><img src="data:image/gif;base64,R0lG"></p>').html);
        expect(doc.querySelectorAll('img'), hasLength(1));
      });
    }

    test('bgcolor is converted even with a <style> background (fwfh ignores it)', () {
      expect(
        style(
          '<style>td{background-color:black}</style>'
              '<table><tr><td bgcolor="white">a</td></tr></table>',
          'td',
        ),
        startsWith('background-color:white;'),
      );
    });

    for (final c in {
      'display:none;display:block': 2,
      '/* display:none */color:red': 2,
      'display:block!important;display:none': 2,
      'display:none!important;display:block': 1,
      'display:block;display:none': 1,
    }.entries) {
      test('effective display of img: ${c.key}', () {
        final doc = parse(_blocked('<p><img style="${c.key}"><img src="data:image/gif;base64,R0lG"></p>').html);
        expect(doc.querySelectorAll('img'), hasLength(c.value));
      });
    }
  });

  group('CSS rewriting creates no markup (#383)', () {
    for (final html in [
      // Taking out the @import joins `</sty` and `le>`.
      '<style>p{}</sty@import url(//x.example/a.css);le><img src="https://track.example/p.png"></style><p>x</p>',
      '<style>p{}</sty@import "//x.example/a.css";le><img src="https://track.example/p.png"></style>',
      // A url() becoming `none`, a closing tag inside a CSS comment.
      '<style>/* </style> */ p{background:url(//x.example/b.png)}</style><p>x</p>',
      '<sty<style>le>p{}</sty@import url(//x.example/a.css);le><img src=https://track.example/p.png></style>',
    ]) {
      test('no remote image escapes from ${html.substring(0, 40)}…', () {
        final out = _blocked(html).html;
        final doc = parse(out);
        expect(doc.querySelectorAll('img').where((i) => i.attributes.containsKey('src')), isEmpty);
        expect(doc.querySelectorAll('style').map((e) => e.text).join(), isNot(contains('<')));
      });
    }
  });
}
