// PostinoProgressBar (#283): a determinate bar glides to a new value, linearly; at once with reduced motion. The
// spoken value is the target's, in steps of 25%.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Widget _bar(double? value, {bool reduced = false}) => MaterialApp(
  theme: PostinoTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: PostinoProgressBar(label: 'Download', value: value),
    ),
  ),
);

double? _shown(WidgetTester tester) =>
    tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value;

void main() {
  final half = PostinoMotion.state ~/ 2;

  testWidgets('the first value is just there; a new one is reached linearly', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_bar(0.2));
    expect(_shown(tester), 0.2);
    await tester.pumpWidget(_bar(0.6));
    await tester.pump(half);
    expect(_shown(tester), closeTo(0.4, 0.01));
    expect(tester.getSemantics(find.byType(PostinoProgressBar)).value, '50%');
    await tester.pump(half);
    expect(_shown(tester), closeTo(0.6, 1e-9));
    handle.dispose();
  });

  testWidgets('indeterminate stays indeterminate', (tester) async {
    await tester.pumpWidget(_bar(null));
    expect(_shown(tester), isNull);
  });

  testWidgets('with reduced motion the bar jumps', (tester) async {
    await tester.pumpWidget(_bar(0.2, reduced: true));
    await tester.pumpWidget(_bar(0.6, reduced: true));
    await tester.pump();
    expect(_shown(tester), 0.6);
  });
}
