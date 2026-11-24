import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';

void main() {
  testWidgets('LitehtmlView prende l\'altezza del contenuto e la aggiorna con la larghezza', (tester) async {
    Widget view(double width) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: LitehtmlView(html: '<p>${'parola ' * 100}</p>', width: width),
      ),
    );

    await tester.pumpWidget(view(400));
    final wide = tester.getSize(find.byType(LitehtmlView));
    expect(wide.width, 400);
    expect(wide.height, greaterThan(40));

    await tester.pumpWidget(view(200));
    expect(tester.getSize(find.byType(LitehtmlView)).height, greaterThan(wide.height));
  });
}
