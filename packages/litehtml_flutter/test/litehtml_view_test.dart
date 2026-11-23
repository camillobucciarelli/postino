import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';

const _html = '''
<table width="100%" bgcolor="#eeeeee"><tr>
  <td width="50%" style="border:1px solid red">uno</td>
  <td width="50%"><img src="x.png" width="120" height="40"></td>
</tr></table>
<p style="font-family: Arial, sans-serif">due parole</p>
''';

void main() {
  test('layout e draw passano dalle callback Dart', () {
    final doc = LitehtmlDocument(_html, 400);
    addTearDown(doc.dispose);

    final height = doc.layout(400);
    final picture = doc.record();
    picture.dispose();

    expect(height, greaterThan(40));
    expect(doc.calls['create_font'], greaterThan(0));
    expect(doc.calls['text_width'], greaterThan(0));
    expect(doc.calls['draw_text'], greaterThan(0));
    expect(doc.calls['draw_image'], 1);
    expect(doc.calls['draw_borders'], greaterThan(0));
    expect(doc.calls['fill_rect'], greaterThan(0));
  });

  test('una larghezza minore allunga il documento', () {
    final doc = LitehtmlDocument('<p>${'parola ' * 200}</p>', 600);
    addTearDown(doc.dispose);

    expect(doc.layout(300), greaterThan(doc.layout(600)));
  });

  test('le media query seguono la larghezza del relayout', () {
    const html =
        '<body style="margin: 0"><style>@media (max-width: 500px) { .wide { display: none; } }</style>'
        '<div class="wide" style="height: 100px"></div><div style="height: 10px"></div>';
    final doc = LitehtmlDocument(html, 600);
    addTearDown(doc.dispose);

    expect(doc.layout(600), 110);
    expect(doc.layout(400), 10);
  });

  test('td height=40 spaziatore dà una riga di 40 px (patch postino)', () {
    const html =
        '<body style="margin: 0"><table width="100%" style="max-width: 300px" cellpadding="0" cellspacing="0">'
        '<tr><td height="40" style="font-size: 0; line-height: 0">&nbsp;</td></tr></table>';
    final doc = LitehtmlDocument(html, 600);
    addTearDown(doc.dispose);

    expect(doc.layout(600), 40);
  });

  testWidgets('LitehtmlView prende l\'altezza del contenuto', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: LitehtmlView(html: _html, width: 400),
        ),
      ),
    );

    final size = tester.getSize(find.byType(LitehtmlView));
    expect(size.width, 400);
    expect(size.height, greaterThan(40));
  });
}
