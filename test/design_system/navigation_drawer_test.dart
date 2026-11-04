import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

void main() {
  testWidgets('only the sliding box paints the active background', (tester) async {
    final theme = PostinoTheme.light();
    final active = theme.extension<PostinoColors>()!.drawerItemBgActive;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: PostinoNavigationDrawer(
            sections: [
              PostinoDrawerSection(
                items: [
                  PostinoDrawerItem(label: 'A', active: true, onTap: () {}),
                  PostinoDrawerItem(label: 'B', onTap: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boxes = find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == active,
    );
    expect(boxes, findsOneWidget);
    for (final ink in tester.widgetList<InkWell>(find.byType(InkWell))) {
      expect(ink.splashFactory, NoSplash.splashFactory);
      expect(ink.overlayColor!.resolve({WidgetState.hovered, WidgetState.pressed}), Colors.transparent);
    }
  });
}
