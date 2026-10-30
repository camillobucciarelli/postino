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
      final out = _blocked(
        '<form action="https://evil.example/x"><p>Testo</p><input></form>',
      ).html;
      expect(out, isNot(contains('<form')));
      expect(out, isNot(contains('evil')));
      expect(out, contains('<p>Testo</p>'));
    });

    test('drops on* attributes', () {
      final out = _blocked(
        '<p onclick="x()" ONMOUSEOVER="y()" class="c">Ciao</p>',
      ).html;
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
      for (final src in [
        'http://t.example/p.gif',
        'https://t.example/p.gif',
        '//t.example/p.gif',
      ]) {
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
      final r = _blocked(
        '<link rel="stylesheet" href="https://t.example/a.css"><p>x</p>',
      );
      expect(r.blocked, isFalse);
      expect(r.html, isNot(contains('<link')));
    });

    test('data: passes, and blocks nothing', () {
      const png = 'data:image/png;base64,iVBORw0KGgo=';
      final r = _blocked(
        '<img src="$png"><p style="background: url($png)">x</p>',
      );
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
      expect(
        _blocked('<p><a href="https://x.example">link</a></p>').blocked,
        isFalse,
      );
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
    String style(String html, String tag) =>
        parse(_blocked(html).html).querySelector(tag)!.attributes['style']!;

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

    test('a table loses a percentage width, keeps px and the rest', () {
      expect(
        style(
          '<table style="width:100%;background:#eee"><tr><td>x</td></tr></table>',
          'table',
        ),
        'background:#eee',
      );
      expect(
        style('<table style="width: 50% !important"></table>', 'table'),
        '',
      );
      expect(
        style('<table style="width:600px;color:red"></table>', 'table'),
        'width:600px;color:red',
      );
    });

    test('contentWidth is measured before stripping', () {
      expect(
        _blocked('<table><tr><td style="width:640px">x</td></tr></table>')
            .width,
        640,
      );
    });
  });
}
