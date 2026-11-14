// PostinoReveal (#283): an element of a column opens and fades in, closes and fades out as it was, and a new content
// fades over the old; nothing moves at the first build or with reduced motion.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Widget _banner(String label, {VoidCallback? onTap}) => SizedBox(
  key: ValueKey(label),
  height: 40,
  child: TextButton(onPressed: onTap, child: Text(label)),
);

Widget _reveal(Widget? child, {Object? contentKey, bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PostinoReveal(contentKey: contentKey, child: child),
          const SizedBox(key: ValueKey('below'), height: 10),
        ],
      ),
    ),
  ),
);

double _height(WidgetTester tester) => tester.getSize(find.byType(PostinoReveal)).height;

void main() {
  final half = PostinoMotion.snackbar ~/ 2;
  final k = PostinoMotion.standard.transform(0.5);

  testWidgets('what the first build shows is just there', (tester) async {
    await tester.pumpWidget(_reveal(_banner('Offline')));
    expect(_height(tester), 40);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('it opens: half the height half way, all of it at the end', (tester) async {
    await tester.pumpWidget(_reveal(null));
    expect(_height(tester), 0);
    await tester.pumpWidget(_reveal(_banner('Offline')));
    await tester.pump(half);
    expect(_height(tester), closeTo(40 * k, 0.5));
    await tester.pump(half);
    expect(_height(tester), 40);
    expect(tester.getTopLeft(find.byKey(const ValueKey('below'))).dy, 40);
  });

  testWidgets('it closes still drawn as it was, out of reach, then leaves the tree', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(_reveal(_banner('Offline', onTap: () => taps++)));
    await tester.pumpWidget(_reveal(null));
    await tester.pump(half);
    expect(_height(tester), closeTo(40 * k, 0.5));
    expect(find.text('Offline'), findsOneWidget);
    expect(find.semantics.byLabel('Offline'), findsNothing);
    expect(Focus.of(tester.element(find.text('Offline'))).canRequestFocus, isFalse);
    await tester.tap(find.text('Offline'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pump(half);
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsNothing);
    expect(_height(tester), 0);
    handle.dispose();
  });

  testWidgets('back before it closed: it opens again from where it was', (tester) async {
    await tester.pumpWidget(_reveal(_banner('Offline')));
    await tester.pumpWidget(_reveal(null));
    await tester.pump(half);
    await tester.pumpWidget(_reveal(_banner('Offline')));
    await tester.pump();
    expect(_height(tester), closeTo(40 * k, 0.5));
    await tester.pumpAndSettle();
    expect(_height(tester), 40);
    expect(find.semantics.byLabel('Offline'), findsOneWidget);
  });

  testWidgets('a new content fades over the old; the same content changes in place', (tester) async {
    await tester.pumpWidget(_reveal(_banner('Scarico'), contentKey: 1));
    await tester.pumpWidget(_reveal(_banner('Scarico al 50%'), contentKey: 1));
    await tester.pump();
    expect(find.text('Scarico'), findsNothing, reason: 'same key: no fade');
    await tester.pumpWidget(_reveal(_banner('Errore'), contentKey: 2));
    await tester.pump(PostinoMotion.snackbar ~/ 2);
    expect(find.text('Scarico al 50%'), findsOneWidget);
    expect(find.text('Errore'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Scarico al 50%'), findsNothing);
    expect(find.text('Errore'), findsOneWidget);
  });

  testWidgets('with reduced motion it opens, closes and swaps at once', (tester) async {
    await tester.pumpWidget(_reveal(null, reduced: true));
    await tester.pumpWidget(_reveal(_banner('Offline'), reduced: true));
    await tester.pump();
    expect(_height(tester), 40);
    await tester.pumpWidget(_reveal(_banner('Errore'), contentKey: 2, reduced: true));
    await tester.pump();
    expect(find.text('Offline'), findsNothing);
    await tester.pumpWidget(_reveal(null, reduced: true));
    await tester.pump();
    expect(find.text('Errore'), findsNothing);
    expect(_height(tester), 0);
  });
}
