// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/atoms/postino_brand_mark_painter.dart';
import 'package:postino/design_system/design_system.dart';

import '../support/golden_grid.dart';

PostinoBrandMarkPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter! as PostinoBrandMarkPainter;

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: child,
  ),
);

void main() {
  testWidgets('plays one cycle, then calls onDone once', (tester) async {
    var done = 0;
    await tester.pumpWidget(_app(PostinoBrandMark(onDone: () => done++)));
    expect(_painter(tester).flapFold, -1);
    await tester.pump(const Duration(milliseconds: 450));
    expect(_painter(tester).letterRise, inExclusiveRange(0, 1));
    expect(done, 0);
    // The controller completes on the first frame past 900 ms.
    await tester.pump(const Duration(milliseconds: 451));
    expect(_painter(tester).letterRise, 1);
    expect(done, 1);
    await tester.pumpAndSettle();
    expect(done, 1);
  });

  testWidgets('with reduced motion shows the final pose at once', (tester) async {
    var done = 0;
    await tester.pumpWidget(_app(PostinoBrandMark(onDone: () => done++), reduced: true));
    expect(_painter(tester).flapFold, 1);
    expect(_painter(tester).letterRise, 1);
    expect(done, 1);
  });

  testComponentGoldens({
    'brand_mark': () => const PostinoBrandMark(),
    // The 0 ms frame: what assets/brand/mark-closed.svg (the native splash, #267) must look like.
    'brand_mark_closed': () => CustomPaint(
      size: const Size.square(128),
      painter: PostinoBrandMarkPainter(const AlwaysStoppedAnimation(0)),
    ),
    'brand_mark_frame': () => CustomPaint(
      size: const Size.square(128),
      painter: PostinoBrandMarkPainter(const AlwaysStoppedAnimation(450 / 900)),
    ),
  });
}
