// HTML fixtures split across lines: the tags are the separators, no whitespace is wanted between fragments.
// ignore_for_file: missing_whitespace_between_adjacent_strings
// Every link of a body becomes an opaque token (#48, ADR 0007); a tap names the link itself, with its own label.

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:postino/features/posta/domain/link_check.dart';
import 'package:postino/features/posta/domain/link_label.dart';
import 'package:postino/features/posta/domain/link_table.dart';

const _nonce = 'abc123';
String _token(int i) => 'https://postino.invalid/l/$_nonce/$i';

void main() {
  group('tokenizeLinks', () {
    test('replaces every a and area href by a token, keeping the original and its label', () {
      final t = tokenizeLinks(
        '<a href="https://www.paypal.com/x">paypal.com</a><area href="https://b.example/"><a>none</a>',
        nonce: _nonce,
      );
      expect(t.html, contains('href="${_token(0)}"'));
      expect(t.html, contains('href="${_token(1)}"'));
      expect(t.html, isNot(contains('paypal.com/x')));
      expect(t.lookup(_token(0)), (href: 'https://www.paypal.com/x', label: 'paypal.com'));
      expect(t.lookup(_token(1))?.href, 'https://b.example/');
      expect(t.lookup(_token(2)), isNull);
    });

    test('two links to one destination keep their own labels', () {
      final t = tokenizeLinks(
        '<a href="https://evil.io">paypal.com</a><a href="https://evil.io/">Continue</a>',
        nonce: _nonce,
      );
      expect(t.lookup(_token(0))?.label, 'paypal.com');
      expect(t.lookup(_token(1))?.label, 'Continue');
    });

    test('a token the sender wrote is replaced; other tokens and spellings find nothing', () {
      final t = tokenizeLinks(
        '<a href="https://postino.invalid/l/guess/0">x</a><a href="https://postino.invalid/l/$_nonce/0">y</a>',
        nonce: _nonce,
      );
      final hrefs = [for (final a in parse(t.html).querySelectorAll('a')) a.attributes['href']];
      expect(hrefs, [_token(0), _token(1)]);
      expect(t.lookup(_token(0))?.href, 'https://postino.invalid/l/guess/0');
      expect(t.lookup(_token(1))?.href, 'https://postino.invalid/l/$_nonce/0');
      expect(t.lookup('https://postino.invalid/l/guess/0'), isNull);
      expect(t.lookup('https://postino.invalid/l/$_nonce/-1'), isNull);
      expect(t.lookup('https://postino.invalid/l/$_nonce/x'), isNull);
      expect(t.lookup('https://postino.invalid/other/$_nonce/0'), isNull);
      expect(t.lookup('https://evil.io/l/$_nonce/0'), isNull);
      expect(t.lookup('::nope'), isNull);
    });

    test('whatever the spelling of the destination, the lookup is exact: :0443, IDN, case need no handling', () {
      final t = tokenizeLinks(
        '<a href="https://evil.io:0443/">paypal.com</a><a href="https://bücher.example/">paypal.com</a>',
        nonce: _nonce,
      );
      final first = t.lookup(_token(0))!;
      expect(first.label, 'paypal.com');
      expect(t.lookup(_token(1))?.label, 'paypal.com');
      expect(linkWarning(Uri.parse(first.href), [first.label])?.domain, 'evil.io');
    });

    test('an in-page jump stays as written and takes no token', () {
      final t = tokenizeLinks('<a href="#sec">top</a><a href="https://e.io/">e.io</a>', nonce: _nonce);
      expect(t.html, contains('href="#sec"'));
      expect(t.lookup(_token(0))?.href, 'https://e.io/');
    });

    test('the href is read as the HTML URL parser reads it: padding and inner tabs and newlines go', () {
      final t = tokenizeLinks('<a href=" \thttps://e.io/pa\nth \n">e.io</a>', nonce: _nonce);
      expect(t.lookup(_token(0))?.href, 'https://e.io/path');
    });

    test('nonces differ per render', () {
      expect(newLinkNonce(), isNot(newLinkNonce()));
      expect(newLinkNonce(), hasLength(32));
    });
  });

  group('label of a link', () {
    String? label(String html) => tokenizeLinks(html, nonce: _nonce).lookup(_token(0))?.label;

    test('plain nested tags keep their text', () {
      expect(label('<a href="https://e.io/"><b>e</b>.<i>io</i></a>'), 'e.io');
      expect(label('<a href="https://www.paypal.com/">paypal.<b>com</b></a>'), 'paypal.com');
      expect(
        label(
          '<table width="600"><tr><td align="center" class="c">'
          '<a href="https://e.io/" target="_blank">e.io</a></td></tr></table>',
        ),
        'e.io',
      );
    });

    test('anything that could alter the label makes it unverifiable', () {
      for (final html in [
        '<a href="https://e.io/">paypal.com<span style="display:none">@e.io</span></a>',
        '<a href="https://e.io/">x<i hidden>y</i></a>',
        '<a href="https://e.io/">x<i aria-hidden="true">y</i></a>',
        '<style>.h{display:none}</style><a href="https://e.io/">a<b class="h">@e.io</b></a>',
        '<style>a{font-size:0}a::before{content:"paypal.com"}</style><a href="https://e.io/">e.io</a>',
        '<body style="x"><a href="https://e.io/">a<b>@e.io</b></a>',
        '<a href="https://e.io/">a<details>@e.io</details></a>',
        '<a href="https://e.io/"></a>',
        '<a href="https://e.io/">www.paypal.com<br>@e.io</a>',
        '<a href="https://e.io/">www.paypal.com<wbr>@e.io</a>',
        '<a href="https://e.io/">e.io<img src="data:,x" alt="@x.io"></a>',
        '<a href="https://e.io/">a<span class="x">b</span></a>',
        '<a href="https://e.io/"><div>e.io</div></a>',
        '<a href="https://e.io/">e.io<rp>x</rp></a>',
        '<a href="https://e.io/"><bdo dir="rtl">oi.e</bdo></a>',
        '<p dir="rtl"><a href="https://e.io/">e.io</a></p>',
        '<font color="#fff"><a href="https://e.io/">e.io</a></font>',
        '<table><tr><td bgcolor="#000"><a href="https://e.io/">e.io</a></td></tr></table>',
        '<a href="https://e.io/" style="color:red">e.io</a>',
        '<a href="https://e.io/">e.io\u202e</a>',
        '<a href="https://e.io/">e\u200b.io</a>',
      ]) {
        expect(label(html), unverifiableText, reason: html);
      }
    });

    test('an unverifiable label warns, with the real domain', () {
      final e = tokenizeLinks('<a href="https://evil.io/"></a>', nonce: _nonce).lookup(_token(0))!;
      expect(linkWarning(Uri.parse(e.href), [e.label])?.unverified, isTrue);
    });
  });
}
