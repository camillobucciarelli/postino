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
}
