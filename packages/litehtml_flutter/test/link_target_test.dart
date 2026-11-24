import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';

const _ring = Color(0xFF123456);

Widget view(String html, ValueChanged<String> onLinkTap) => WidgetsApp(
  color: const Color(0xFFFFFFFF),
  // Il focus parte da fuori dal corpo, come nell'app.
  builder: (context, _) => Focus(
    autofocus: true,
    child: Align(
      alignment: Alignment.topLeft,
      child: LitehtmlView(
        html: html,
        width: 400,
        onLinkTap: onLinkTap,
        focusColor: _ring,
        errorBuilder: (context, error) => Text('ripiego $error'),
      ),
    ),
  ),
);

/// Gli anelli di focus dipinti in questo momento.
Finder get rings =>
    find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter.runtimeType.toString() == '_RingPainter');

const _html =
    '<table><tr><td>colonna <a href="https://a.it">prima</a><br><a href="https://b.it">seconda</a></td> '
    '<td><a href="https://c.it">terza</a></td></tr></table>';

void main() {
  testWidgets('Tab raggiunge i link in ordine di documento con l\'anello di focus, Invio li attiva', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(view(_html, tapped.add));
    expect(rings, findsNothing);

    final order = <String>[];
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      order.add(tapped.last);
      expect(rings, findsOneWidget);
    }

    // La cella destra («terza») sta più in alto di «seconda» ma viene dopo nel documento.
    expect(order, ['https://a.it', 'https://b.it', 'https://c.it']);
  });

  testWidgets('Invio senza un link col focus non chiama onLinkTap', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(view(_html, tapped.add));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(tapped, isEmpty);
  });
}
