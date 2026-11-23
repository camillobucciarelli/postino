// The twin of postino_icon_button.dart: the primary disc (Rispondi, #369) in brand, brand-hover under the pointer.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

void main() {
  testWidgets('primary: a brand disc, brand-hover when hovered, the icon in on-brand', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PostinoTheme.light(),
        home: Scaffold(
          body: PostinoIconButton(icon: PostinoIcons.reply, label: 'Rispondi', primary: true, onPressed: () {}),
        ),
      ),
    );
    const c = PostinoColors.light;
    final button = tester.widget<IconButton>(find.byType(IconButton));
    final background = button.style!.backgroundColor!;
    expect(background.resolve({}), c.brand);
    expect(background.resolve({WidgetState.hovered}), c.brandHover);
    expect(button.color, c.onBrand);
  });
}
