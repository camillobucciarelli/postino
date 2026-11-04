// HTML fixtures split across lines: the tags are the separators, no whitespace is wanted between fragments.
// ignore_for_file: missing_whitespace_between_adjacent_strings
// Deceptive links (#48, ADR 0007): which registrable domain a link's text shows against where it goes.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/features/posta/domain/link_check.dart';
import 'package:postino/features/posta/domain/original_document.dart';
import 'package:postino/features/posta/domain/punycode.dart';

void main() {
  group('registrableDomain', () {
    test('keeps site and suffix, drops subdomains', () {
      expect(registrableDomain('paypal.com'), 'paypal.com');
      expect(registrableDomain('www.paypal.com'), 'paypal.com');
      expect(registrableDomain('a.b.paypal.com'), 'paypal.com');
      expect(registrableDomain('paypal.com.evil.io'), 'evil.io');
      expect(registrableDomain('mail.example.co.uk'), 'example.co.uk');
      expect(registrableDomain('Example.COM'), 'example.com');
    });

    test('an IP address is its own domain', () {
      expect(registrableDomain('192.168.0.1'), '192.168.0.1');
    });
  });

  group('deceptiveLink', () {
    LinkWarning? check(String url, String text) => deceptiveLink(Uri.parse(url), text);

    test('a text showing another registrable domain warns, with the real one', () {
      expect(check('https://paypal.com.evil.io/login', 'paypal.com'), (
        domain: 'paypal.com.evil.io',
        punycode: false,
        unverified: false,
      ));
      expect(check('https://evil.io/x', 'https://www.paypal.com/account')?.domain, 'evil.io');
      expect(check('http://evil.io', 'Vai su www.paypal.com ora')?.domain, 'evil.io');
      expect(check('https://203.0.113.9/x', 'paypal.com')?.domain, '203.0.113.9');
    });

    test('the same site, subdomains or not, does not warn', () {
      expect(check('https://paypal.com/login', 'paypal.com'), isNull);
      expect(check('https://www.paypal.com/login', 'paypal.com'), isNull);
      expect(check('https://paypal.com/login', 'https://www.paypal.com'), isNull);
      expect(check('https://mail.example.co.uk/x', 'www.example.co.uk'), isNull);
      expect(check('https://PAYPAL.com/x', 'paypal.COM'), isNull);
    });

    test('a text that names no domain does not warn', () {
      expect(check('https://evil.io', 'Clicca qui'), isNull);
      expect(check('https://evil.io', 'Scarica report.pdf'), isNull);
      expect(check('https://evil.io', ''), isNull);
      expect(check('https://evil.io', 'versione 3.14'), isNull);
    });

    test('trailing punctuation does not hide a domain; every domain shown counts', () {
      expect(check('https://evil.io', 'https://paypal.com.')?.domain, 'evil.io');
      expect(check('https://paypal.com./x', 'paypal.com'), isNull);
      expect(check('https://paypal.com/x', 'ada@paypal.com'), isNull);
      expect(check('https://evil.io', '(www.paypal.com),')?.domain, 'evil.io');
      expect(check('https://paypal.com/x', 'www.paypal.com e www.evil.io')?.domain, 'paypal.com');
    });

    test('linkWarning fails closed: no text found means a warning, unverified', () {
      expect(linkWarning(Uri.parse('https://evil.io/x'), <String>[]), (
        domain: 'evil.io',
        punycode: false,
        unverified: true,
      ));
      expect(linkWarning(Uri.parse('https://xn--pypal-4ve.com/'), <String>[])?.punycode, isTrue);
      expect(linkWarning(Uri.parse('https://paypal.com/x'), const ['paypal.com']), isNull);
      expect(linkWarning(Uri.parse('https://paypal.com/x'), const ['ok', 'paypal.com']), isNull);
      expect(linkWarning(Uri.parse('https://evil.io/x'), const ['Clicca', 'paypal.com'])?.unverified, isFalse);
      expect(linkWarning(Uri.parse('mailto:a@evil.io'), <String>[]), isNull);
    });

    test('mailto: never warns', () {
      expect(check('mailto:aiuto@evil.io', 'aiuto@paypal.com'), isNull);
      expect(check('mailto:aiuto@evil.io', 'paypal.com'), isNull);
    });

    test('punycode is decoded and flagged', () {
      final w = check('https://xn--pypal-4ve.com/', 'paypal.com');
      expect(w, (domain: 'pаypal.com', punycode: true, unverified: false));
      // The shown text is the decoded form of the real host: honest, no warning.
      expect(check('https://xn--pypal-4ve.com/', 'pаypal.com'), isNull);
    });
  });

  group('punycode', () {
    test('decodes known labels', () {
      expect(decodeHost('xn--bcher-kva.example'), 'bücher.example');
      expect(decodeHost('xn--mnchen-3ya.de'), 'münchen.de');
      expect(decodeHost('XN--BCHER-KVA.example'), 'bücher.example');
      expect(decodeHost('paypal.com'), 'paypal.com');
    });

    test('a malformed label stays as it is', () {
      expect(decodeHost('xn--!!.com'), 'xn--!!.com');
      expect(hasPunycode('xn--!!.com'), isTrue);
      expect(hasPunycode('example.com'), isFalse);
    });
  });

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

  group('originalDocument', () {
    test('allows only data: images by default, remote ones on request; never script', () {
      final blocked = originalDocument('<p>x</p>', allowRemote: false);
      expect(blocked, contains("img-src data:;"));
      expect(blocked, contains("default-src 'none'"));
      expect(blocked, contains('<p>x</p>'));
      expect(originalDocument('<p>x</p>', allowRemote: true), contains('img-src data: https: http:;'));
    });

    test('takes out what a CSP does not stop: refresh, base, link, other http-equiv; DNS prefetch and Referer off', () {
      final doc = originalDocument(
        '<head><meta http-equiv="refresh" content="0;url=https://evil.io"><base href="https://evil.io/">'
        '<link rel="prefetch" href="https://evil.io/x"><meta http-equiv="Content-Security-Policy" content="x">'
        '<meta charset="utf-8"></head><body><p>x</p></body>',
        allowRemote: true,
      );
      expect(doc, isNot(contains('refresh')));
      expect(doc, isNot(contains('<base')));
      expect(doc, isNot(contains('<link')));
      expect(
        originalDocument('<a href="https://a.example/" target="_blank">a</a>', allowRemote: false),
        allOf(contains('<a href="https://a.example/">a</a>'), isNot(contains('target'))),
      );
      expect(doc, isNot(contains('content="x"')));
      expect(doc, contains('<meta charset="utf-8">'));
      expect(doc, startsWith('<meta http-equiv="x-dns-prefetch-control" content="off">'));
      expect(doc, contains('<p>x</p>'));
    });
  });
}
