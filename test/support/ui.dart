import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Finder icon(PostinoIconData data) =>
    find.byWidgetPredicate((w) => w is PostinoIcon && w.icon == data);

Finder get starIcon => icon(PostinoIcons.star);

/// Opens the NavigationDrawer from the AppBar's `menu`.
Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(icon(PostinoIcons.menu));
  await tester.pumpAndSettle();
}

/// The color of the Account bar on [row], or null without one.
Color? accountBar(WidgetTester tester, Finder row) {
  final bar = find.descendant(
    of: find.descendant(
      of: row,
      matching: find.byKey(const ValueKey('account-bar')),
    ),
    matching: find.byType(ColoredBox),
  );
  return bar.evaluate().isEmpty ? null : tester.widget<ColoredBox>(bar).color;
}
