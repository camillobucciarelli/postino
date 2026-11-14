// The gate of the shortcuts: a list-only key (the arrows) moves only while the list says it has the focus.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/features/posta/presentation/posta_shortcuts.dart';

Future<List<int>> _moves(WidgetTester tester, ListCursor cursor, LogicalKeyboardKey key) async {
  final moves = <int>[];
  cursor.move = moves.add;
  final focus = FocusNode();
  addTearDown(focus.dispose);
  await tester.pumpWidget(
    PostaShortcuts(
      cursor: cursor,
      child: Focus(focusNode: focus, autofocus: true, child: const SizedBox()),
    ),
  );
  await tester.sendKeyEvent(key);
  return moves;
}

void main() {
  testWidgets('an arrow does nothing while the list does not say it has the focus', (tester) async {
    expect(await _moves(tester, ListCursor(), LogicalKeyboardKey.arrowDown), isEmpty, reason: 'no list plugged in');
  });

  testWidgets('an arrow moves while the list has the focus, not when it has not', (tester) async {
    expect(await _moves(tester, ListCursor()..listFocused = () => true, LogicalKeyboardKey.arrowDown), [1]);
    expect(await _moves(tester, ListCursor()..listFocused = () => false, LogicalKeyboardKey.arrowDown), isEmpty);
  });

  testWidgets('j moves wherever the focus is', (tester) async {
    expect(await _moves(tester, ListCursor(), LogicalKeyboardKey.keyJ), [1]);
  });
}
