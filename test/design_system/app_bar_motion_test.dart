// PostinoAppBar (#283): actions that arrive once the content is there fade in; at the first build they are just
// there; with reduced motion at once. While they fade in the screen reader reads them once.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Widget _bar({required bool ready, bool reduced = false}) => MaterialApp(
  theme: PostinoTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: PostinoAppBar(
        title: 'Titolo',
        actions: [if (ready) PostinoIconButton(icon: PostinoIcons.tag, label: 'Etichette', onPressed: () {})],
      ),
    ),
  ),
);

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.ancestor(of: find.byType(PostinoIconButton), matching: find.byType(FadeTransition)).first,
    )
    .opacity
    .value;

void main() {
  testWidgets('actions there at the first build are just there', (tester) async {
    await tester.pumpWidget(_bar(ready: true));
    expect(_opacity(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('actions that arrive fade in: half way partly there, whole at the end, read once', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_bar(ready: false));
    await tester.pumpWidget(_bar(ready: true));
    await tester.pump(PostinoMotion.state ~/ 2);
    expect(_opacity(tester), inExclusiveRange(0, 1));
    expect(find.semantics.byPredicate((n) => n.tooltip == 'Etichette'), findsOneWidget, reason: 'read once');
    await tester.pump(PostinoMotion.state ~/ 2);
    expect(_opacity(tester), 1);
    handle.dispose();
  });

  testWidgets('with reduced motion they are there at once', (tester) async {
    await tester.pumpWidget(_bar(ready: false, reduced: true));
    await tester.pumpWidget(_bar(ready: true, reduced: true));
    await tester.pump();
    expect(_opacity(tester), 1);
  });
}
