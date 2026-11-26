import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';

Widget view(String html, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: LitehtmlView(
      html: html,
      width: width,
      errorBuilder: (context, error) => Text('ripiego ${error.failure.name}'),
    ),
  ),
);

void main() {
  final long = '<p>${'parola ' * 100}</p>';

  testWidgets('prende l\'altezza del contenuto e la aggiorna con la larghezza', (tester) async {
    await tester.pumpWidget(view(long, 400));
    final wide = tester.getSize(find.byType(LitehtmlView));
    expect(wide.width, 400);
    expect(wide.height, greaterThan(40));

    await tester.pumpWidget(view(long, 200));
    expect(tester.getSize(find.byType(LitehtmlView)).height, greaterThan(wide.height));
  });

  testWidgets('un nuovo html alla stessa larghezza rifà il documento', (tester) async {
    await tester.pumpWidget(view('<body style="margin: 0"><div style="height: 30px"></div>', 400));
    expect(tester.getSize(find.byType(LitehtmlView)).height, 30);

    await tester.pumpWidget(view('<body style="margin: 0"><div style="height: 70px"></div>', 400));
    expect(tester.getSize(find.byType(LitehtmlView)).height, 70);
  });

  testWidgets('HTML rifiutato → errorBuilder, poi un html valido torna a rendere', (tester) async {
    await tester.pumpWidget(view('${'<div>' * 200}x', 400));
    expect(find.text('ripiego tooDeep'), findsOneWidget);

    // Larghezza nuova con lo stesso HTML rifiutato: nessun nuovo tentativo, resta il ripiego.
    await tester.pumpWidget(view('${'<div>' * 200}x', 300));
    expect(find.text('ripiego tooDeep'), findsOneWidget);

    await tester.pumpWidget(view('<body style="margin: 0"><div style="height: 30px"></div>', 400));
    expect(find.text('ripiego tooDeep'), findsNothing);
    expect(tester.getSize(find.byType(LitehtmlView)).height, 30);
  });

  testWidgets('layout oltre il budget → errorBuilder', (tester) async {
    await tester.pumpWidget(view('${'<table><tr><td>' * 20}x', 400));
    expect(find.text('ripiego layout'), findsOneWidget);
  });
}
