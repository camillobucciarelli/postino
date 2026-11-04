// Quote and signature recognition (#47, ThreadView): one real-looking fixture per client,
// through the same cleaning the Conversazione does first.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/html_text.dart';
import 'package:postino/features/posta/domain/quoted_text.dart';
import 'package:postino/features/posta/domain/safe_html.dart';

import '../../support/value_equality.dart';

String _fixture(String name) =>
    File('test/fixtures/quote/$name').readAsStringSync();

BodyParts _html(String name) =>
    splitHtml(prepareHtml(_fixture(name), allowRemote: false).html);

String _text(String? html) =>
    htmlText(html ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  group('quote', () {
    test('Gmail: gmail_quote with its gmail_attr header', () {
      final p = _html('gmail_reply.html');
      expect(_text(p.quote), startsWith('Il giorno mar 14 ott 2026'));
      expect(_text(p.quote), endsWith('modifiche del cliente.'));
      expect(_text(p.body), 'Ciao Giulia, ti giro il PDF firmato dal cliente.');
      expect(p.bodyVisible, isTrue);
    });

    test('Apple Mail: blockquote type=cite, its header inside', () {
      final p = _html('apple_mail.html');
      expect(
        _text(p.quote),
        contains('Bruno Verdi <bruno@example.com> wrote:'),
      );
      expect(_text(p.quote), contains('Ti va una cena venerdì?'));
      expect(_text(p.body), 'Va bene, ci vediamo alle 20.');
    });

    test('Thunderbird: moz-cite-prefix and blockquote type=cite together', () {
      final p = _html('thunderbird.html');
      expect(
        _text(p.quote),
        startsWith('On 28/10/26 10:00, Bruno Verdi wrote:'),
      );
      expect(_text(p.quote), contains('Ti va una cena venerdì?'));
      expect(_text(p.body), 'Confermo, porto io il vino.');
    });

    test('Outlook: appendonsend, divRplyFwdMsg and everything after', () {
      final p = _html('outlook.html');
      expect(_text(p.quote), startsWith('Da: Ada Okafor'));
      expect(_text(p.quote), endsWith("Ecco l'ordine confermato."));
      expect(_text(p.body), 'Grazie, ricevuto.');
    });

    test('Outlook: an address as text after the header stays escaped', () {
      final p = splitHtml(
        '<p>Ok</p><div id="divRplyFwdMsg">Da:</div>Ada &lt;ada@example.com&gt;',
      );
      expect(p.quote, contains('&lt;ada@example.com&gt;'));
      expect(_text(p.quote), contains('<ada@example.com>'));
    });

    test('<title> in no part, whatever the cleaning did (#63)', () {
      const raw =
          '<html><head><title>Oggetto segreto</title><style>p{color:red}</style></head>'
          '<body><p>Ok</p><div class="gmail_quote">Citato</div>'
          '<div class="gmail_signature">Firma</div></body></html>';
      for (final p in [
        splitHtml(raw),
        splitHtml(prepareHtml(raw, allowRemote: false).html),
      ]) {
        for (final part in [p.body, p.quote, p.signature]) {
          expect(part, isNotNull);
          expect(part, isNot(contains('Oggetto segreto')));
        }
        expect(p.quote, contains('p{color:red}'));
      }
    });

    test('Yahoo: yahoo_quoted', () {
      final p = _html('yahoo.html');
      expect(
        _text(p.quote),
        contains('Bruno Verdi <bruno@example.com> ha scritto:'),
      );
      expect(_text(p.body), 'Perfetto, a venerdì!');
    });

    test('plain text: the trailing > block and the header line before it', () {
      final p = splitText(_fixture('plain_reply.txt'));
      expect(
        p.quote,
        startsWith('Il giorno mar 27 ott 2026 alle ore 09:12 Bruno Verdi\n'),
      );
      expect(p.quote, endsWith('> Bruno'));
      expect(p.quote, contains('> > Avevamo detto giovedì.'));
      expect(p.body, 'Va bene, alle 20 da Mario.');
    });

    test('plain text: a > block in the middle is not the trailing quote', () {
      final p = splitText('> Ti va una cena?\n\nSì, alle 20.');
      expect(p.quote, isNull);
      expect(p.body, '> Ti va una cena?\n\nSì, alle 20.');
    });

    for (final name in [
      'gmail_forward.html',
      'apple_forward.html',
      'outlook_forward.html',
    ]) {
      test('a forward is never a quote: $name', () {
        final p = _html(name);
        expect(p.quote, isNull);
        expect(foldBody(p, repeated: false).folded, isNull);
      });
    }

    test('a forward is never a quote: plain text', () {
      final p = splitText(_fixture('plain_forward.txt'));
      expect(p.quote, isNull);
      expect(p.body, contains('Il tuo biglietto per Milano è confermato.'));
    });

    test('a message that is only a quote is not folded', () {
      final html = _html('gmail_quote_only.html');
      expect(html.quote, isNotNull);
      expect(html.bodyVisible, isFalse);
      final shown = foldBody(html, repeated: false);
      expect(shown.folded, isNull);
      expect(_text(shown.body), contains('Ti va una cena venerdì?'));

      final text = splitText('\nOn Tue, Oct 27, 2026 Bruno wrote:\n> Ciao');
      final plain = foldBody(text, repeated: false);
      expect(plain.folded, isNull);
      expect(plain.body, 'On Tue, Oct 27, 2026 Bruno wrote:\n> Ciao');
    });

    test('a reply folds its quote behind «…», the rest shows', () {
      final shown = foldBody(_html('gmail_reply.html'), repeated: false);
      expect(
        _text(shown.body),
        'Ciao Giulia, ti giro il PDF firmato dal cliente.',
      );
      expect(_text(shown.folded), startsWith('Il giorno mar 14 ott'));
    });
  });

  group('signature', () {
    test('Gmail: gmail_signature, without its «-- » prefix in the body', () {
      final p = _html('gmail_reply.html');
      expect(
        _text(p.signature),
        'Ada Okafor Okafor Legal · Via Dante 12, Milano',
      );
      expect(_text(p.body), isNot(contains('--')));
    });

    test('Thunderbird: moz-signature (not the one inside the quote)', () {
      final p = _html('thunderbird.html');
      expect(_text(p.signature), '-- Luca Neri Enoteca Neri');
      expect(p.signatureKey, 'luca neri enoteca neri');
    });

    test('a forward without own signature does not take the original one', () {
      final p = splitHtml(
        '<p>Ciao</p><div class="gmail_quote">---------- Forwarded message ---------'
        '<div class="gmail_signature">Ada</div></div>',
      );
      expect(p.signature, isNull);
      expect(p.quote, isNull);
    });

    test('Outlook: #Signature', () {
      final p = _html('outlook.html');
      expect(_text(p.signature), 'Marco Lenti Ufficio acquisti');
    });

    test('plain text: after a «-- » line, before the quote', () {
      final p = splitText(_fixture('plain_reply.txt'));
      expect(p.signature, '-- \nAda Okafor\nOkafor Legal');
      expect(p.signatureKey, 'ada okafor okafor legal');
    });

    test('the same signature in HTML and text normalizes the same', () {
      final html = splitHtml(
        '<p>Ciao</p><div class="gmail_signature">Ada  Okafor<br>Okafor Legal</div>',
      );
      final text = splitText('Ciao\n-- \nAda Okafor\nOkafor Legal');
      expect(html.signatureKey, text.signatureKey);
    });

    test('a repeated signature folds, the first one shows', () {
      final first = splitText('Ciao\n-- \nAda Okafor');
      final again = splitText('A presto\n-- \nAda  Okafor ');
      final other = splitText('Ok\n-- \nBruno');
      expect(
        repeatedSignatures([
          first.signatureKey,
          null,
          other.signatureKey,
          again.signatureKey,
        ]),
        [false, false, false, true],
      );
      final shown = foldBody(first, repeated: false);
      expect((shown.signature, shown.folded), ('-- \nAda Okafor', null));
      final folded = foldBody(again, repeated: true);
      expect((folded.body, folded.signature), ('A presto', null));
      expect(folded.folded, '-- \nAda  Okafor');
    });

    test('a repeated signature with nothing else stays visible', () {
      final p = splitText('-- \nAda Okafor');
      expect(foldBody(p, repeated: true).body, '-- \nAda Okafor');
    });
  });

  group('card tables with a marker (#63)', () {
    for (final (attr, pick) in [
      ('class="gmail_quote"', (BodyParts p) => p.original),
      ('id="Signature"', (BodyParts p) => p.signature),
    ]) {
      test('$attr takes the decorated div, not the bare table', () {
        final p = splitHtml(
          prepareHtml(
            '<p>ciao</p><table $attr style="width:100%;border:1px solid red">'
            '<tr><td>x</td></tr></table>',
            allowRemote: false,
          ).html,
        );
        final taken = pick(p)!;
        expect(taken, contains('<div'));
        expect(taken, contains('border:1px solid red'));
        expect(p.body, isNot(contains('border:1px')));
        expect(p.body, isNot(contains('<div')));
      });
    }
  });

  test('BodyParts compares by value (#94)', () {
    BodyParts parts({
      String original = 'o',
      String body = 'b',
      bool bodyVisible = true,
      String? signature = 's',
      String? quote = 'q',
    }) => BodyParts(
      original: original,
      body: body,
      bodyVisible: bodyVisible,
      signature: signature,
      quote: quote,
    );
    expectValueEquality(parts, [
      parts(original: 'x'),
      parts(body: 'x'),
      parts(bodyVisible: false),
      parts(signature: null),
      parts(quote: null),
    ]);
  });
}
