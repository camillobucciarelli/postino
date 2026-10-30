import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

// The empty state fills the detail pane, where a short window gives it a tight height.
Widget _pane(double height, double textScale) => MaterialApp(
  theme: PostinoTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Material(
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 447,
          height: height,
          child: const PostinoEmptyState(
            title: 'Niente di nuovo',
            body: 'I messaggi compaiono qui appena arrivano.',
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final (h, s) in [(226.0, 1.0), (150.0, 1.0), (300.0, 2.0)]) {
    testWidgets('no overflow in a ${h}px pane at text ${s * 100}%', (t) async {
      await t.pumpWidget(_pane(h, s));
      expect(t.takeException(), isNull);
      expect(find.text('Niente di nuovo'), findsOneWidget);
    });
  }
}
