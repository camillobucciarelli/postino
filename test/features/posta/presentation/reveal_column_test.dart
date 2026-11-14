// RevealColumn (#283): children that come and go open and close with a fade, the leaving ones out of reach; the first
// build is just there, a column empty at first opens its first children, reduced motion is instant.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/reveal_column.dart';

Widget _row(String label, {VoidCallback? onTap}) => SizedBox(
  key: ValueKey(label),
  height: 40,
  child: TextButton(onPressed: onTap, child: Text(label)),
);

Widget _column(List<Widget> children, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RevealColumn(children: children),
          const SizedBox(key: ValueKey('below'), height: 10),
        ],
      ),
    ),
  ),
);

double _height(WidgetTester tester) => tester.getSize(find.byType(RevealColumn)).height;

void main() {
  final half = PostinoMotion.snackbar ~/ 2;
  final k = PostinoMotion.standard.transform(0.5);

  testWidgets('what the first build shows is just there', (tester) async {
    await tester.pumpWidget(_column([_row('A'), _row('B')]));
    expect(_height(tester), 80);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('empty at first, the first child opens: half way half of it, all of it at the end', (tester) async {
    await tester.pumpWidget(_column([]));
    expect(_height(tester), 0);
    await tester.pumpWidget(_column([_row('A')]));
    await tester.pump(half);
    expect(_height(tester), closeTo(40 * k, 0.5));
    await tester.pump(half);
    expect(_height(tester), 40);
    expect(tester.getTopLeft(find.byKey(const ValueKey('below'))).dy, 40);
  });

  testWidgets('one that goes closes at its place, out of reach, then leaves the tree', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(_column([_row('A', onTap: () => taps++), _row('B')]));
    await tester.pumpWidget(_column([_row('B')]));
    await tester.pump(half);
    expect(_height(tester), closeTo(40 + 40 * k, 0.5));
    expect(
      tester.getTopLeft(find.text('A')).dy,
      lessThan(tester.getTopLeft(find.text('B')).dy),
      reason: 'at its place',
    );
    expect(find.semantics.byLabel('A'), findsNothing);
    expect(Focus.of(tester.element(find.text('A'))).canRequestFocus, isFalse);
    await tester.tap(find.text('A'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pump(half);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing);
    expect(_height(tester), 40);
    handle.dispose();
  });

  testWidgets('with reduced motion they come and go at once', (tester) async {
    await tester.pumpWidget(_column([], reduced: true));
    await tester.pumpWidget(_column([_row('A')], reduced: true));
    await tester.pump();
    expect(_height(tester), 40);
    await tester.pumpWidget(_column([], reduced: true));
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(_height(tester), 0);
  });
}
