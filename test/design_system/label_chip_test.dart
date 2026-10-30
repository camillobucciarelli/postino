import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

void main() {
  testWidgets('a very long label shrinks inside a narrow Wrap', (tester) async {
    final name = 'Etichetta lunghissima ' * 10;
    await tester.pumpWidget(
      MaterialApp(
        theme: PostinoTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: Wrap(children: [PostinoLabelChip(name: name)]),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(PostinoLabelChip)).width,
      lessThanOrEqualTo(320),
    );
    expect(find.bySemanticsLabel(name), findsOneWidget);
  });
}
