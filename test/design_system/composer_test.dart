// The composer's organisms: the rich editor (formats, shortcuts, semantics) and the sender picker.
import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

const _labels = PostinoFormatLabels(
  bold: 'Grassetto',
  italic: 'Corsivo',
  underline: 'Sottolineato',
  strikethrough: 'Barrato',
  link: 'Link',
  bulletList: 'Elenco puntato',
  numberedList: 'Elenco numerato',
  linkUrl: 'Indirizzo del link',
  insert: 'Inserisci',
  cancel: 'Annulla',
);

Widget _app(Widget child) => MaterialApp(
  theme: PostinoTheme.light(),
  home: Scaffold(body: child),
);

/// An editor with [text] in it, focused, with the whole text selected when [select].
Future<QuillController> _editor(WidgetTester tester, {String text = 'ciao', bool select = true}) async {
  final controller = QuillController.basic();
  addTearDown(controller.dispose);
  controller.document.insert(0, text);
  await tester.pumpWidget(
    _app(
      PostinoRichEditor(
        controller: controller,
        label: 'Corpo del messaggio',
        placeholder: 'Scrivi il messaggio',
        labels: _labels,
      ),
    ),
  );
  await tester.tap(find.byType(QuillEditor));
  await tester.pump();
  if (select) {
    controller.updateSelection(TextSelection(baseOffset: 0, extentOffset: text.length), ChangeSource.local);
    await tester.pump();
  }
  return controller;
}

/// The inline attributes on the first run of the document.
Map<String, dynamic> _attributes(QuillController c) => c.document.toDelta().first.attributes ?? const {};

Future<void> _chord(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

/// Shortcuts: `meta` on macOS, `control` elsewhere (flutter_quill reads the platform once).
void _onMac(String name, Future<void> Function(WidgetTester) body) => testWidgets(name, (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  try {
    await body(tester);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
});

void main() {
  group('PostinoRichEditor', () {
    _onMac('typing updates the Delta of the controller', (tester) async {
      final controller = await _editor(tester, text: '', select: false);
      // The remote value quill keeps ends with the document's newline.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(text: 'Ciao Ada\n', selection: TextSelection.collapsed(offset: 8)),
      );
      await tester.pump();
      expect(controller.document.toPlainText(), 'Ciao Ada\n');
    });

    _onMac('the bold button formats the selection and reads as toggled', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = await _editor(tester);
      final bold = find.semantics.byLabel('Grassetto');
      expect(bold, isNot(isSemantics(isToggled: true)));
      await tester.tap(find.byTooltip('Grassetto'));
      await tester.pump();
      expect(_attributes(controller), {'bold': true});
      expect(bold, isSemantics(isToggled: true));
      semantics.dispose();
    });

    _onMac('Cmd+B makes the selection bold', (tester) async {
      final controller = await _editor(tester);
      await _chord(tester, LogicalKeyboardKey.keyB);
      expect(_attributes(controller), {'bold': true});
    });

    _onMac('Cmd+Shift+X strikes the selection through', (tester) async {
      final controller = await _editor(tester);
      await _chord(tester, LogicalKeyboardKey.keyX, shift: true);
      expect(_attributes(controller), {'strike': true});
    });

    _onMac('Cmd+Shift+B does not quote (a format outside #35)', (tester) async {
      final controller = await _editor(tester);
      await _chord(tester, LogicalKeyboardKey.keyB, shift: true);
      expect(controller.document.toDelta().toJson(), [
        {'insert': 'ciao\n'},
      ]);
    });

    _onMac('the link dialog links the selection', (tester) async {
      final controller = await _editor(tester);
      await tester.tap(find.byTooltip('Link'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Indirizzo del link'), 'https://example.com');
      await tester.tap(find.text('Inserisci'));
      await tester.pumpAndSettle();
      expect(_attributes(controller), {'link': 'https://example.com'});
    });

    _onMac('Cmd+K with nothing selected inserts the URL as the link', (tester) async {
      final controller = await _editor(tester, text: '', select: false);
      await _chord(tester, LogicalKeyboardKey.keyK);
      await tester.enterText(find.widgetWithText(TextField, 'Indirizzo del link'), 'https://example.com');
      await tester.tap(find.text('Inserisci'));
      await tester.pumpAndSettle();
      expect(controller.document.toDelta().toJson(), [
        {
          'insert': 'https://example.com',
          'attributes': {'link': 'https://example.com'},
        },
        {'insert': '\n'},
      ]);
    });

    _onMac('every button and the editor have a semantic label', (tester) async {
      final semantics = tester.ensureSemantics();
      await _editor(tester);
      for (final label in [
        'Grassetto',
        'Corsivo',
        'Sottolineato',
        'Barrato',
        'Link',
        'Elenco puntato',
        'Elenco numerato',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      expect(find.semantics.byLabel('Corpo del messaggio'), isSemantics(isTextField: true, isMultiline: true));
      semantics.dispose();
    });
  });

  group('PostinoSenderPicker', () {
    const options = <PostinoSenderOption>[
      (id: 'a1', mark: (color: PostinoAccountColor.sky, initial: 'L'), address: 'lavoro@example.com'),
      (id: 'a2', mark: (color: PostinoAccountColor.rose, initial: 'P'), address: 'personale@example.com'),
    ];

    testWidgets('opens from the keyboard and a choice calls onSelected', (tester) async {
      final semantics = tester.ensureSemantics();
      String? chosen;
      await tester.pumpWidget(
        _app(PostinoSenderPicker(options: options, selectedId: 'a1', onSelected: (id) => chosen = id, label: 'Da')),
      );
      expect(find.semantics.byLabel('Da: lavoro@example.com'), isSemantics(isButton: true));
      expect(find.text('personale@example.com'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('personale@example.com'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, 'a2');
      semantics.dispose();
    });
  });
}
