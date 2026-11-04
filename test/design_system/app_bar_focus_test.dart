import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

/// The ring of an AppBar button is outside the button (`focus-offset`): the bar must not clip it.
void main() {
  for (final (name, back) in [('back', true), ('menu', false)]) {
    testWidgets('the focus ring of the AppBar $name button is not clipped', (tester) async {
      final theme = PostinoTheme.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            drawer: const Drawer(),
            body: RepaintBoundary(
              key: const ValueKey('shot'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [PostinoAppBar(title: 'Titolo', onBack: back ? () {} : null)],
              ),
            ),
          ),
        ),
      );
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      final ring = theme.extension<PostinoColors>()!.focusRing;
      final button = find.byType(PostinoFocusRing);
      expect(button, findsOneWidget);
      Focus.of(tester.element(button)).requestFocus();
      await tester.pump();
      final r = tester.getRect(button);
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
      final image = (await tester.runAsync(boundary.toImage))!;
      final bytes = (await tester.runAsync(image.toByteData))!;
      int px(double x, double y) {
        final o = (y.floor() * image.width + x.floor()) * 4;
        return (bytes.getUint8(o + 3) << 24) |
            (bytes.getUint8(o) << 16) |
            (bytes.getUint8(o + 1) << 8) |
            bytes.getUint8(o + 2);
      }

      // Middle of the stroke, 3px outside each edge.
      for (final (edge, x, y) in [
        ('top', r.center.dx, r.top - 3),
        ('left', r.left - 3, r.center.dy),
        ('bottom', r.center.dx, r.bottom + 3),
        ('right', r.right + 3, r.center.dy),
      ]) {
        final got = Color(px(x, y));
        // Anti-aliasing may soften the stroke a little; clipped, it would be the bar's background.
        for (final (a, b) in [(got.r, ring.r), (got.g, ring.g), (got.b, ring.b)]) {
          expect((a - b).abs(), lessThan(0.15), reason: '$edge edge: $got');
        }
      }
    });
  }
}
