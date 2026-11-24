import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';

/// Il corpo in una `SelectionArea`, sotto un `Text` come nella Conversazione.
Widget area(String html, FocusNode focus) => MaterialApp(
  home: Scaffold(
    body: SelectionArea(
      focusNode: focus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [LitehtmlView(html: html, width: 400, errorBuilder: (_, e) => Text('ripiego $e'))],
      ),
    ),
  ),
);

/// Intercetta il testo che la selezione mette negli appunti.
List<String> watchClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return copied;
}

Future<void> shortcut(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}

const _html =
    '<body style="margin: 0; font-size: 20px"> '
    '<p style="margin: 0">uno<br>due</p> '
    '<table cellspacing="0" cellpadding="0"><tr><td>a</td><td>b</td></tr></table> '
    '<p style="margin: 0; width: 120px">parole su piu righe</p>';

void main() {
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

  testWidgets('Cmd+A e Cmd+C copiano il corpo con gli a capo di <br>, celle e paragrafi', (tester) async {
    final copied = watchClipboard(tester);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(area(_html, focus));
    focus.requestFocus();
    await tester.pump();

    await shortcut(tester, LogicalKeyboardKey.keyA);
    await shortcut(tester, LogicalKeyboardKey.keyC);

    expect(copied.last, 'uno\ndue\na\nb\nparole su piu righe');
  }, variant: macOS);

  testWidgets('trascinare col mouse copia solo il tratto selezionato', (tester) async {
    final copied = watchClipboard(tester);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(area(_html, focus));
    final origin = tester.getTopLeft(find.byType(LitehtmlView));

    // Da metà di "uno" (20 px per carattere col font di test) a metà di "due" sulla riga sotto.
    final drag = await tester.startGesture(origin + const Offset(25, 10), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await drag.moveTo(origin + const Offset(45, 30));
    await tester.pump();
    await drag.up();
    await tester.pump();
    await shortcut(tester, LogicalKeyboardKey.keyC);

    expect(copied.last, 'no\ndu');
  }, variant: macOS);

  testWidgets('doppio clic seleziona la parola, triplo clic tutto il paragrafo su più righe', (tester) async {
    final copied = watchClipboard(tester);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(area(_html, focus));
    final para = tester.getTopLeft(find.byType(LitehtmlView)) + const Offset(30, 70);

    final gesture = await tester.startGesture(para, kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.down(para);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await shortcut(tester, LogicalKeyboardKey.keyC);
    expect(copied.last, 'parole');

    await gesture.down(para);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await shortcut(tester, LogicalKeyboardKey.keyC);
    expect(copied.last, 'parole su piu righe');
  }, variant: macOS);

  testWidgets('Maiusc+freccia estende la selezione da tastiera', (tester) async {
    final copied = watchClipboard(tester);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(area(_html, focus));
    final origin = tester.getTopLeft(find.byType(LitehtmlView));

    final drag = await tester.startGesture(origin + const Offset(1, 10), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await drag.moveTo(origin + const Offset(21, 10));
    await drag.up();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pump();
    await shortcut(tester, LogicalKeyboardKey.keyC);

    expect(copied.last, 'un');
  }, variant: macOS);

  testWidgets('touch: pressione lunga seleziona la parola e mostra le maniglie', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(area(_html, focus));
    final origin = tester.getTopLeft(find.byType(LitehtmlView));

    await tester.longPressAt(origin + const Offset(30, 10));
    await tester.pumpAndSettle();

    final handles = find.byWidgetPredicate((w) => w.runtimeType.toString().contains('SelectionHandle'));
    expect(handles, findsWidgets);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('i frammenti trasparenti coincidono col testo disegnato', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(area(_html, focus));
    final origin = tester.getTopLeft(find.byType(LitehtmlView));

    final uno = find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == 'uno');
    expect(tester.getTopLeft(uno), origin);
    expect(tester.getSize(uno).width, 60);
  });
}
