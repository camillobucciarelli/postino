// PostinoQrCode (ADR 0019): one image for the screen reader, dark modules on a light ground in both themes.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Widget _qr(Brightness b) => MaterialApp(
  theme: b == Brightness.light ? PostinoTheme.light() : PostinoTheme.dark(),
  home: const Scaffold(
    body: Center(
      child: PostinoQrCode(data: 'P1ABCD', semanticLabel: 'QR del codice'),
    ),
  ),
);

void main() {
  testWidgets('square at its size, read as one image by its name', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_qr(Brightness.light));
    expect(tester.getSize(find.byType(PostinoQrCode)), const Size.square(240));
    expect(tester.getSemantics(find.byType(PostinoQrCode)), matchesSemantics(label: 'QR del codice', isImage: true));
    semantics.dispose();
  });

  for (final b in Brightness.values) {
    testWidgets('$b: a light ground under dark modules', (tester) async {
      await tester.pumpWidget(_qr(b));
      final c = Theme.of(tester.element(find.byType(PostinoQrCode))).extension<PostinoColors>()!;
      final (light, dark) = c.surface.computeLuminance() > c.ink.computeLuminance()
          ? (c.surface, c.ink)
          : (c.ink, c.surface);
      final paint = find.descendant(of: find.byType(PostinoQrCode), matching: find.byType(CustomPaint));
      // The ground first, over the whole square, then the modules.
      expect(
        paint,
        paints
          ..rect(rect: Offset.zero & const Size.square(240), color: light)
          ..rect(color: dark),
      );
    });
  }
}
