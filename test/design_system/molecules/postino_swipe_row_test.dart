// PostinoSwipeRow (#147, #376): an Azione that takes the row away sends it off the screen with the Azione's colour
// behind, where it stays while the owner keeps it away; then it is in place at once. Any other Azione, or a drag
// short of the threshold, brings it back sliding.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

const _width = 400.0;

/// Left Archivia (takes the row away), right Segna come letto (keeps it).
Widget _row({bool away = false, List<PostinoSwipeSide>? swiped}) => MaterialApp(
  theme: PostinoTheme.light(),
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: _width,
      child: PostinoSwipeRow(
        left: (label: 'Archivia', icon: PostinoIcons.archive, tone: PostinoSwipeTone.archive),
        right: (label: 'Letto', icon: PostinoIcons.mailOpen, tone: PostinoSwipeTone.read),
        away: away,
        onSwipe: (side) {
          swiped?.add(side);
          return side == PostinoSwipeSide.left;
        },
        child: const ColoredBox(
          color: Color(0xFFFFFFFF),
          child: SizedBox(height: 60, width: _width, child: Text('Riga')),
        ),
      ),
    ),
  ),
);

double _x(WidgetTester tester) => tester.getTopLeft(find.text('Riga')).dx;

/// The colour behind the row, if it shows.
Color? _behind(WidgetTester tester) {
  final box = find.descendant(of: find.byType(ExcludeSemantics), matching: find.byType(ColoredBox));
  return box.evaluate().isEmpty ? null : tester.widget<ColoredBox>(box.first).color;
}

PostinoColors _colors(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(PostinoSwipeRow))).extension<PostinoColors>()!;

/// A drag of [dx] with a frame under the finger, as on a device, then released.
Future<void> _drag(WidgetTester tester, double dx) async {
  final g = await tester.startGesture(tester.getCenter(find.byType(PostinoSwipeRow)));
  await g.moveBy(Offset(dx.sign * 20, 0));
  await g.moveBy(Offset(dx - dx.sign * 20, 0));
  await tester.pump();
  await g.up();
  await tester.pump();
}

void main() {
  testWidgets('Archivia: from where it was released the row goes on off the screen, the colour behind', (tester) async {
    final swiped = <PostinoSwipeSide>[];
    await tester.pumpWidget(_row(swiped: swiped));
    await _drag(tester, -200);
    expect(swiped, [PostinoSwipeSide.left]);
    final released = _x(tester);
    expect(released, lessThan(0));
    await tester.pumpWidget(_row(away: true, swiped: swiped));
    await tester.pump(PostinoMotion.swipeDismiss ~/ 2);
    expect(_x(tester), inExclusiveRange(-_width, released), reason: 'on its way out, past where it was released');
    expect(_behind(tester), _colors(tester).swipeArchiveBg, reason: 'still armed');
    await tester.pump(PostinoMotion.swipeSettle - PostinoMotion.swipeDismiss ~/ 2);
    expect(_x(tester), greaterThan(-_width), reason: 'it takes swipeDismiss, not swipeSettle');
    await tester.pump(PostinoMotion.swipeDismiss);
    expect(_x(tester), -_width, reason: 'off the screen');
    expect(_behind(tester), _colors(tester).swipeArchiveBg);
    await tester.pump(const Duration(seconds: 1));
    expect(_x(tester), -_width, reason: 'it stays out while away');
  });

  testWidgets('off the screen it takes no drag', (tester) async {
    final swiped = <PostinoSwipeSide>[];
    await tester.pumpWidget(_row(swiped: swiped));
    await _drag(tester, -200);
    await tester.pumpWidget(_row(away: true, swiped: swiped));
    await tester.pump(PostinoMotion.swipeDismiss);
    await _drag(tester, 200);
    await tester.pump(const Duration(seconds: 1));
    expect(_x(tester), -_width);
    expect(_behind(tester), _colors(tester).swipeArchiveBg);
    expect(swiped, [PostinoSwipeSide.left]);
  });

  testWidgets('no longer away (stayed, or Annulla): in place at once, nothing behind', (tester) async {
    await tester.pumpWidget(_row());
    await _drag(tester, -200);
    await tester.pumpWidget(_row(away: true));
    await tester.pump(PostinoMotion.swipeDismiss ~/ 2);
    await tester.pumpWidget(_row());
    expect(_x(tester), 0, reason: 'not sliding back from the side');
    expect(_behind(tester), isNull);
    await tester.pumpAndSettle();
    expect(_x(tester), 0);
  });

  testWidgets('Segna come letto: the row goes back in place, nothing behind', (tester) async {
    final swiped = <PostinoSwipeSide>[];
    await tester.pumpWidget(_row(swiped: swiped));
    await _drag(tester, 200);
    expect(swiped, [PostinoSwipeSide.right]);
    await tester.pump(PostinoMotion.swipeSettle ~/ 2);
    expect(_x(tester), inExclusiveRange(0, PostinoSize.swipeThreshold));
    await tester.pump(PostinoMotion.swipeSettle ~/ 2);
    expect(_x(tester), 0, reason: 'back in swipeSettle');
    await tester.pumpAndSettle();
    expect(_x(tester), 0);
    expect(_behind(tester), isNull);
  });

  testWidgets('held short of the threshold: the Azione shows, not armed', (tester) async {
    await tester.pumpWidget(_row());
    final g = await tester.startGesture(tester.getCenter(find.byType(PostinoSwipeRow)));
    await g.moveBy(const Offset(-20, 0));
    await g.moveBy(const Offset(-(PostinoSize.swipeThreshold - 30), 0));
    await tester.pump();
    expect(_behind(tester), _colors(tester).swipeNeutralBg);
    await g.moveBy(const Offset(-40, 0));
    await tester.pump();
    expect(_behind(tester), _colors(tester).swipeArchiveBg);
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('short of the threshold: back in place, nothing done', (tester) async {
    final swiped = <PostinoSwipeSide>[];
    await tester.pumpWidget(_row(swiped: swiped));
    await _drag(tester, -(PostinoSize.swipeThreshold - 10));
    await tester.pumpAndSettle();
    expect(swiped, isEmpty);
    expect(_x(tester), 0);
  });

  testWidgets('with reduced motion the row is back at once: the list takes it away without motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final swiped = <PostinoSwipeSide>[];
    await tester.pumpWidget(_row(swiped: swiped));
    await _drag(tester, -200);
    expect(swiped, [PostinoSwipeSide.left]);
    expect(_x(tester), 0);
    expect(_behind(tester), isNull);
  });
}
