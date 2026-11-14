// PostinoSizeFade (#282): fades and opens/closes the height with its animation; a leaving element is out of reach.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Widget _fade(Animation<double> visibility, {bool leaving = false, VoidCallback? onTap}) => MaterialApp(
  home: Scaffold(
    body: Column(
      children: [
        PostinoSizeFade(
          visibility: visibility,
          leaving: leaving,
          child: SizedBox(
            height: 40,
            child: TextButton(onPressed: onTap, child: const Text('Riga')),
          ),
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('half way: half the height, and the same curve for height and fade', (tester) async {
    await tester.pumpWidget(_fade(const AlwaysStoppedAnimation(0.5)));
    final k = PostinoMotion.standard.transform(0.5);
    expect(tester.getSize(find.byType(PostinoSizeFade)).height, closeTo(40 * k, 0.01));
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition).last).opacity.value, closeTo(k, 1e-9));
    expect(tester.getTopLeft(find.text('Riga')).dy, lessThan(20), reason: 'closes from the bottom, top in place');
  });

  testWidgets('at rest it is the element itself', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_fade(kAlwaysCompleteAnimation, onTap: () => taps++));
    expect(tester.getSize(find.byType(PostinoSizeFade)).height, 40);
    await tester.tap(find.text('Riga'));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Riga'), findsOneWidget);
  });

  testWidgets('leaving: no taps, no focus, nothing read', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(_fade(const AlwaysStoppedAnimation(0.5), leaving: true, onTap: () => taps++));
    await tester.tap(find.text('Riga'), warnIfMissed: false);
    expect(taps, 0);
    expect(find.bySemanticsLabel('Riga'), findsNothing);
    expect(Focus.of(tester.element(find.text('Riga'))).canRequestFocus, isFalse);
    handle.dispose();
  });
}
