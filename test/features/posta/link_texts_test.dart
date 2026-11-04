// HTML fixtures split across lines: the tags are the separators, no whitespace is wanted between fragments.
// ignore_for_file: missing_whitespace_between_adjacent_strings
// Deceptive links (#48, ADR 0007): which registrable domain a link's text shows against where it goes.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/features/posta/domain/link_check.dart';

import 'package:postino/features/posta/domain/link_texts.dart';

void main() {
  group('linkTexts', () {
    const html =
        '<a href="https://www.paypal.com/x">uno</a><a href="https://www.paypal.com/x"><b>due</b></a><a>none</a>';

    test('lists the texts by href', () {
      expect(linkTexts(html), {
        'https://www.paypal.com/x': ['uno', 'due'],
      });
    });

    test('a link with a plain nested tag keeps its text; one that could hide text is unverifiable', () {
      final links = linkTexts(
        '<a href="https://www.paypal.com/">paypal.<b>com</b></a>'
        '<a href="https://evil.io/">paypal.com<span style="display:none">@evil.io</span></a>'
        '<a href="https://evil.io/2">x<i hidden>y</i></a><a href="https://evil.io/3">x<i aria-hidden="true">y</i></a>',
      );
      expect(links['https://www.paypal.com/'], ['paypal.com']);
      expect(links['https://evil.io/'], [unverifiableText]);
      expect(links['https://evil.io/2'], [unverifiableText]);
      expect(links['https://evil.io/3'], [unverifiableText]);
      expect(linkWarning(Uri.parse('https://www.paypal.com/'), links['https://www.paypal.com/']!), isNull);
      expect(linkWarning(Uri.parse('https://evil.io/'), links['https://evil.io/']!)?.unverified, isTrue);
      expect(
        linkTexts(
          '<style>.h{display:none}</style><a href="https://e.io/">a<b class="h">@e.io</b></a>',
        )['https://e.io/'],
        [unverifiableText],
      );
    });

    test('other ways to alter a label also fail closed', () {
      String? text(String html) => linkTexts(html)['https://e.io/']?.single;
      expect(
        text('<style>span{display:none}</style><a href="https://e.io/">a<span>@e.io</span></a>'),
        unverifiableText,
      );
      expect(text('<body style="x"><a href="https://e.io/">a<b>@e.io</b></a>'), unverifiableText);
      expect(text('<a href="https://e.io/">a<details>@e.io</details></a>'), unverifiableText);
      expect(text('<a href="https://e.io/"></a>'), unverifiableText);
      expect(text('<a href="https://e.io/">www.paypal.com<br>@e.io</a>'), unverifiableText);
      expect(text('<a href="https://e.io/">www.paypal.com<wbr>@e.io</a>'), unverifiableText);
      expect(text('<a href="https://e.io/">e.io<img src="data:,x" alt="@x.io"></a>'), unverifiableText);
      expect(text('<a href="https://e.io/">a<span class="x">b</span></a>'), unverifiableText);
      expect(text('<a href="https://e.io/"><div>e.io</div></a>'), unverifiableText);
      expect(text('<a href="https://e.io/"><b>e</b>.<i>io</i></a>'), 'e.io');
      expect(text('<font color="#fff"><a href="https://e.io/">e.io</a></font>'), unverifiableText);
      expect(
        text('<table><tr><td bgcolor="#000"><a href="https://e.io/">e.io</a></td></tr></table>'),
        unverifiableText,
      );
      expect(
        text(
          '<table width="600"><tr><td align="center" class="c"><a href="https://e.io/" target="_blank">e.io</a></td></tr></table>',
        ),
        'e.io',
      );
      expect(text('<a href="https://e.io/">e.io\u202e</a>'), unverifiableText);
      expect(text('<a href="https://e.io/">e\u200b.io</a>'), unverifiableText);
      expect(text('<a href="https://e.io/">e.io<rp>x</rp></a>'), unverifiableText);
      expect(text('<a href="https://e.io/"><bdo dir="rtl">oi.e</bdo></a>'), unverifiableText);
      expect(text('<p dir="rtl"><a href="https://e.io/">e.io</a></p>'), unverifiableText);
      expect(
        text(
          '<style>a{font-size:0}a::before{content:"paypal.com";font-size:16px}</style><a href="https://e.io/">e.io</a>',
        ),
        unverifiableText,
      );
      expect(text('<a href="https://e.io/" style="color:red">e.io</a>'), unverifiableText);
      expect(text('<div style="x"><p><a href="https://e.io/">e.io</a></p></div>'), unverifiableText);
      expect(text('<a href="https://e.io/">e.io</a>'), 'e.io');
      expect(text('<a href="https://e.io/">e.<b>io</b></a>'), 'e.io');
    });

    test('textsOf collects every label of the destination, exact or normalised', () {
      final links = linkTexts('<a href="https://evil.io">paypal.com</a><a href="https://evil.io/">Continue</a>');
      final texts = textsOf(links, 'https://evil.io/').toList();
      expect(texts, containsAll(['paypal.com', 'Continue']));
      expect(textsOf(links, 'https://evil.io').toList(), containsAll(['paypal.com', 'Continue']));
      expect(linkWarning(Uri.parse('https://evil.io/'), texts)?.unverified, isFalse);
    });

    test('textsOf matches an exact or normalised URL', () {
      final links = linkTexts('<a href="https://a.example">uno</a><a href="https://b.example/p">due</a>');
      expect(textsOf(links, 'https://a.example'), ['uno']);
      expect(textsOf(links, 'https://a.example/'), ['uno']);
      expect(textsOf(links, 'https://c.example/'), isEmpty);
    });
  });

  group('textsOf, one destination in many spellings', () {
    Iterable<String> texts(String href, String url) =>
        textsOf(linkTexts('<a href="$href">paypal.com</a><a href="https://evil.io/">Continue</a>'), url);

    test('Unicode and punycode hosts collide', () {
      expect(texts('https://bücher.example/', 'https://xn--bcher-kva.example/'), contains('paypal.com'));
      expect(texts('https://xn--bcher-kva.example/', 'https://bücher.example/'), contains('paypal.com'));
      expect(texts('https://BÜCHER.example/', 'https://xn--bcher-kva.example/'), contains('paypal.com'));
    });

    test('case, trailing dot, default port, userinfo, fragment and empty path collide', () {
      for (final other in [
        'HTTPS://EVIL.IO/',
        'https://evil.io./',
        'https://evil.io:443/',
        'https://u:p@evil.io/',
        'https://evil.io/#top',
        'https://evil.io',
        'https://evil.io:/',
      ]) {
        expect(texts('https://evil.io/', other), containsAll(['paypal.com', 'Continue']), reason: other);
      }
      expect(texts('http://evil.io:80/', 'http://evil.io/'), contains('paypal.com'));
      expect(texts('https://evil.io:8443/', 'https://evil.io/').toList(), ['Continue']);
    });

    test('backslashes, tabs, newlines and percent-encoding collide', () {
      expect(texts(r'https://evil.io\a', 'https://evil.io/a'), contains('paypal.com'));
      expect(texts('https://evil.io/a', 'https://evi\tl.io/a'), contains('paypal.com'));
      expect(texts('https://evil.io/%7Euser/a%20b', 'https://evil.io/~user/a b'), contains('paypal.com'));
      expect(texts('https://evil.io/caf\u00e9', 'https://evil.io/caf%C3%A9'), contains('paypal.com'));
      expect(texts('https://evil.io/%7euser', 'https://evil.io/%7Euser'), contains('paypal.com'));
      expect(texts('https://evil.io/?q=%41', 'https://evil.io/?q=A'), contains('paypal.com'));
    });

    test('IPv4 in any base, IPv6 forms, percent-encoded host, dot segments collide', () {
      for (final other in ['http://0x7f.1/', 'http://2130706433/', 'http://0177.0.0.1/', 'http://127.1/']) {
        expect(texts('http://127.0.0.1/', other), contains('paypal.com'), reason: other);
      }
      expect(texts('http://[::1]/', 'http://[0:0:0:0:0:0:0:1]/'), contains('paypal.com'));
      expect(texts('http://[::FFFF:127.0.0.1]/', 'http://[0:0:0:0:0:ffff:7f00:1]/'), contains('paypal.com'));
      expect(texts('https://ex%61mple.io/', 'https://example.io/'), contains('paypal.com'));
      expect(texts('https://evil.io/a/../b', 'https://evil.io/b'), contains('paypal.com'));
      expect(texts('https://evil.io/./a/', 'https://evil.io/a/'), contains('paypal.com'));
    });

    test('a link that cannot be keyed makes every destination unverifiable', () {
      final links = linkTexts('<a href="https://\uff45vil.io/">paypal.com</a><a href="https://ok.io/">Continue</a>');
      expect(textsOf(links, 'https://evil.io/'), contains(unverifiableText));
      expect(
        textsOf(linkTexts('<a href="/relative">x</a><a href="mailto:a@b.io">y</a>'), 'https://evil.io/').toList(),
        isEmpty,
      );
    });

    test('a URL that cannot be read fails closed', () {
      expect(textsOf(linkTexts('<a href="https://a.io/">x</a>'), '::nope'), [unverifiableText]);
      expect(textsOf(linkTexts('<a href="https://a.io/">x</a>'), 'https:///'), [unverifiableText]);
    });
  });
}
