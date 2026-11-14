// PostinoFadeSwitcher (#283): the new content fades in over the old, which is out of reach while it fades out.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Widget _switcher(String label, {bool reduced = false, VoidCallback? onTap}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: PostinoFadeSwitcher(
        child: TextButton(key: ValueKey(label), onPressed: onTap, child: Text(label)),
      ),
    ),
  ),
);

double _opacity(WidgetTester tester, String label) => tester
    .widget<FadeTransition>(find.ancestor(of: find.text(label), matching: find.byType(FadeTransition)).first)
    .opacity
    .value;

void main() {
  final half = PostinoMotion.state ~/ 2;

  testWidgets('the first content is just there', (tester) async {
    await tester.pumpWidget(_switcher('Uno'));
    expect(_opacity(tester, 'Uno'), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('half way both are drawn, the old one out of reach; at the end only the new one', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(_switcher('Uno', onTap: () => taps++));
    final focus = Focus.of(tester.element(find.text('Uno')))..requestFocus();
    await tester.pump();
    await tester.pumpWidget(_switcher('Due'));
    await tester.pump(half);
    final k = PostinoMotion.standard.transform(0.5);
    expect(_opacity(tester, 'Due'), closeTo(k, 0.05));
    expect(_opacity(tester, 'Uno'), closeTo(k, 0.05));
    expect(find.semantics.byLabel('Uno'), findsNothing, reason: 'the fade does not read twice');
    expect(find.semantics.byLabel('Due'), findsOneWidget);
    expect(focus.hasFocus, isFalse);
    expect(Focus.of(tester.element(find.text('Uno'))).canRequestFocus, isFalse);
    await tester.tap(find.text('Uno'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pump(half);
    await tester.pumpAndSettle();
    expect(find.text('Uno'), findsNothing);
    expect(_opacity(tester, 'Due'), 1);
    handle.dispose();
  });

  testWidgets('with reduced motion the swap is instant', (tester) async {
    await tester.pumpWidget(_switcher('Uno', reduced: true));
    await tester.pumpWidget(_switcher('Due', reduced: true));
    await tester.pump();
    expect(find.text('Uno'), findsNothing);
    expect(_opacity(tester, 'Due'), 1);
  });
}
