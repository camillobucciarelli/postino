// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: child,
  ),
);

void main() {
  var taps = 0;
  final app = PostinoBrandIntro(
    child: Center(
      child: TextButton(onPressed: () => taps++, child: const Text('App')),
    ),
  );
  setUp(() => taps = 0);

  testWidgets('covers the app for one cycle, then leaves', (tester) async {
    await tester.pumpWidget(_app(app));
    expect(find.byType(PostinoBrandMark), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(PostinoBrandMark), findsNothing);
  });

  testWidgets('under the cover the app takes taps, Tab and Enter, and is read by the screen reader', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(app));
    expect(find.byType(PostinoBrandMark), findsOneWidget);
    expect(find.bySemanticsLabel('App'), findsOneWidget);
    await tester.tap(find.text('App'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 2);
    semantics.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('leaves by the wall clock when no frame is drawn (window hidden in the tray)', (tester) async {
    await tester.pumpWidget(_app(app));
    // Time passes without frames, as for a window started hidden at login.
    await tester.binding.delayed(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byType(PostinoBrandMark), findsNothing);
  });

  testWidgets('with reduced motion shows no cover', (tester) async {
    await tester.pumpWidget(_app(app, reduced: true));
    expect(find.byType(PostinoBrandMark), findsNothing);
    expect(find.text('App'), findsOneWidget);
  });
}
