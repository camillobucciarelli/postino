// PostinoListDetailLayout (#365): on iOS below 900 a swipe from the left edge of the full-page detail closes it,
// past a third of the window; a short one, one away from the edge, one on the two panes or on Android does nothing.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Widget _layout(Size size, TargetPlatform platform, VoidCallback onClose) => MaterialApp(
  theme: PostinoTheme.light().copyWith(platform: platform),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(size: size),
      child: Scaffold(
        body: PostinoListDetailLayout(
          list: const Text('lista'),
          detail: const ColoredBox(
            color: Colors.white,
            child: SizedBox.expand(child: Text('dettaglio')),
          ),
          detailKey: 1,
          empty: const SizedBox(),
          onClose: onClose,
          resizeLabel: 'Larghezza lista',
          resizeValueLabel: (w) => '$w',
        ),
      ),
    ),
  ),
);

Future<int> _swipe(
  WidgetTester tester,
  Size size, {
  double from = 5,
  required double by,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var closed = 0;
  await tester.pumpWidget(_layout(size, platform, () => closed++));
  await tester.pumpAndSettle();
  // Slow, so it is no flick.
  await tester.timedDragFrom(Offset(from, 400), Offset(by, 0), const Duration(seconds: 1));
  await tester.pumpAndSettle();
  return closed;
}

void main() {
  const phone = Size(390, 844);

  testWidgets('below 900 a swipe from the left edge past a third closes the detail', (tester) async {
    expect(await _swipe(tester, phone, by: 200), 1);
  });

  testWidgets('a short swipe from the edge does nothing', (tester) async {
    expect(await _swipe(tester, phone, by: 60), 0);
  });

  testWidgets('a swipe that starts away from the edge does nothing', (tester) async {
    expect(await _swipe(tester, phone, from: 100, by: 250), 0);
  });

  testWidgets('from 900, two panes, the swipe does nothing', (tester) async {
    expect(await _swipe(tester, const Size(1200, 800), by: 500), 0);
  });

  testWidgets('on Android, which has its own Indietro, the swipe does nothing', (tester) async {
    expect(await _swipe(tester, phone, by: 200, platform: TargetPlatform.android), 0);
  });
}
