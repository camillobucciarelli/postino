// The twin of postino_shortcut_tooltip.dart (#369): «Nome · scorciatoia» with the pointer and the keyboard, the
// name only after a touch, nothing of it for the screen reader.
import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

const _key = ValueKey('Archivia');

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: PostinoTheme.light(),
      home: Scaffold(
        body: Center(
          child: PostinoIconButton(
            key: _key,
            icon: PostinoIcons.archive,
            label: 'Archivia',
            shortcut: 'E',
            onPressed: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('pointer: «Nome · scorciatoia»', (tester) async {
    await _pump(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(_key)));
    await tester.pumpAndSettle();
    expect(find.text('Archivia · E'), findsOneWidget);
  });

  testWidgets('keyboard: Tab onto it shows «Nome · scorciatoia»; leaving it hides it', (tester) async {
    await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Archivia · E'), findsOneWidget);

    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Archivia · E'), findsNothing);
  });

  testWidgets('touch: a long press shows the name only', (tester) async {
    await _pump(tester);
    await tester.longPress(find.byKey(_key));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Archivia'), findsOneWidget);
    expect(find.text('Archivia · E'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('the screen reader hears the name only, not the shortcut', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(tester.getSemantics(find.bySemanticsLabel('Archivia')).tooltip, isEmpty);
    expect(find.bySemanticsLabel(RegExp('·')), findsNothing);
    semantics.dispose();
  });
}
