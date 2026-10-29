import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/features/posta/presentation/body_text.dart';

void main() {
  test('HTML loses its tags, styles and entities, keeping the lines', () {
    const html =
        '<html><head><style>p { color: red }</style></head><body>'
        '<div dir="ltr">Ciao Ada,<br>ci vediamo\n alle 20 da Mario?</div>'
        '<p>Porto io il vino &amp; il dolce&#33;&nbsp;&#x263A;</p></body></html>';
    expect(
      bodyText(const MessageBody(html, BodyKind.html)),
      'Ciao Ada,\nci vediamo alle 20 da Mario?\nPorto io il vino & il dolce! ☺',
    );
  });

  test('plain text stays as it is, <addresses> included', () {
    const text = 'Ciao,\r\nscrivi a <bruno@example.com>\r\n';
    expect(
      bodyText(const MessageBody(text, BodyKind.testo)),
      'Ciao,\r\nscrivi a <bruno@example.com>',
    );
  });

  test('out-of-range numeric entities become U+FFFD instead of throwing', () {
    const html = '<p>a&#x110000;b&#xD800;c&#0;d&#99999999999;e</p>';
    expect(
      bodyText(const MessageBody(html, BodyKind.html)),
      'a\uFFFDb\uFFFDc\uFFFDd\uFFFDe',
    );
  });
}
