// The twin of postino_snackbar_lift.dart (#369): a bar fixed at the bottom of a pane lifts the snackbars of the
// PostinoSnackbarHost above itself while it is there.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

void _noop() {}

PostinoBarAction _a(String label, {bool primary = false}) =>
    PostinoBarAction(icon: PostinoIcons.star, label: label, onPressed: _noop, primary: primary);

void main() {
  testWidgets('a snackbar shows above the bottom bar, and back at the bottom once the bar is gone', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 800)
      ..devicePixelRatio = 1
      ..viewPadding = const FakeViewPadding(bottom: 34)
      ..padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);
    final show = GlobalKey();
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: PostinoTheme.light(),
        home: PostinoSnackbarHost(
          child: ValueListenableBuilder(
            valueListenable: shown,
            builder: (context, on, _) => Column(
              key: show,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (on)
                  PostinoActionBar(
                    moreLabel: 'Altre azioni',
                    placement: PostinoActionBarPlacement.bottom,
                    groups: [
                      [_a('Archivia'), _a('Elimina')],
                      [_a('Rispondi', primary: true)],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(PostinoSnackbarLift.of(show.currentContext!)!.value.$2, greaterThan(0));
    ScaffoldMessenger.of(show.currentContext!).showSnackBar(const SnackBar(content: Text('Archiviata')));
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(PostinoActionBar));
    expect(tester.getRect(find.text('Archiviata')).bottom, lessThanOrEqualTo(bar.top));

    shown.value = false;
    await tester.pumpAndSettle();
    expect(PostinoSnackbarLift.of(show.currentContext!)!.value.$2, 0);
    expect(tester.getRect(find.text('Archiviata')).bottom, greaterThan(bar.top));
  });
}
