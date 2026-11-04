// Etichette in Posta (#107): the picker from the Conversazione's button, from `l` and from the context menu of a
// row; ticking puts an Etichetta on every message of the Conversazione through the offline queue, unticking or the
// × of a chip takes it off with «Annulla»; «Crea» creates and assigns; the name is validated; the chips of the rows.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/posta_shortcuts.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

late Harness h;
late FakeMailProvider gmail;

DateTime _day(int d) => DateTime.utc(2026, 10, d, 9);

/// Conversazione t: m1 (Viaggi) and m2 (latest, none); Conversazione o: o1 (Viaggi).
Future<void> _start(WidgetTester tester, {Size size = const Size(1600, 900)}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  gmail = await h.addAccount('a1');
  gmail.labels.add(const Label(id: 'Label_13', name: 'Fatture', kind: LabelKind.etichetta));
  gmail
    ..deliver(
      msg('m1', conversationId: 't', subject: 'Cena', date: _day(1), isRead: true, labelIds: ['INBOX', 'Label_12']),
    )
    ..deliver(msg('m2', conversationId: 't', subject: 'Re: Cena', date: _day(2), isRead: true))
    ..deliver(
      msg('o1', conversationId: 'o', subject: 'Altro', date: _day(3), isRead: true, labelIds: ['INBOX', 'Label_12']),
    );
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

/// Bounded pumps, never pumpAndSettle once a Snackbar shows: it ticks every second.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(pumpEventQueue);
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await _settle(tester);
}

void _onMac(String name, Future<void> Function(WidgetTester) body) => testWidgets(name, (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  final semantics = tester.ensureSemantics();
  try {
    await body(tester);
  } finally {
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  }
});

Finder _row(String latest) => find.byKey(ValueKey('row-a1-$latest'));
Finder get _button => find.byTooltip('Etichette');
Finder _tile(String name) => find.widgetWithText(PostinoCheckboxTile, name);
Finder get _field => find.descendant(of: find.byKey(const ValueKey('label-search')), matching: find.byType(TextField));
Finder get _snackbar => find.byType(PostinoSnackbar);
Finder get _undo => find.widgetWithText(PostinoButton, 'Annulla');

bool _ticked(WidgetTester tester, String name) => tester.widget<PostinoCheckboxTile>(_tile(name)).value;

/// The label calls that reached the Provider since [from], comparable.
List<(String, String, bool)> _calls([int from = 0]) => gmail.labelCalls.sublist(from);

FocusNode _buttonFocus(WidgetTester tester) =>
    tester.widget<PostinoIconButton>(find.ancestor(of: _button, matching: find.byType(PostinoIconButton))).focusNode!;

Future<void> _escape(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await _settle(tester);
}

void main() {
  _onMac('the button opens the picker: ticked when on a message; a tick puts it on every message, no snackbar', (
    tester,
  ) async {
    await _start(tester);
    await _tap(tester, _row('m2'));
    await _tap(tester, _button);

    expect(find.byType(PostinoLabelPicker), findsOneWidget);
    expect(_ticked(tester, 'Viaggi'), isTrue);
    expect(_ticked(tester, 'Fatture'), isFalse);
    expect(find.bySemanticsLabel('Etichette, 1 selezionata'), findsOneWidget);

    final from = gmail.labelCalls.length;
    await _tap(tester, _tile('Fatture'));
    expect(_calls(from), unorderedEquals([('m1', 'Label_13', true), ('m2', 'Label_13', true)]));
    expect(_ticked(tester, 'Fatture'), isTrue);
    expect(_snackbar, findsNothing);
  });

  _onMac('unticking takes it off the messages that have it, once «Etichetta tolta» beside the list; Annulla puts it '
      'back; Esc gives the focus back to the button', (tester) async {
    await _start(tester);
    await _tap(tester, _row('m2'));
    await _tap(tester, _button);

    final from = gmail.labelCalls.length;
    await _tap(tester, _tile('Viaggi'));
    expect(_calls(from), [('m1', 'Label_12', false)]);
    expect(_ticked(tester, 'Viaggi'), isFalse);
    // List and Conversazione side by side: one snackbar, not one per pane.
    expect(_snackbar, findsOneWidget);
    expect(find.text('Etichetta «Viaggi» tolta'), findsOneWidget);

    await _escape(tester);
    expect(find.byType(PostinoLabelPicker), findsNothing);
    expect(_buttonFocus(tester).hasPrimaryFocus, isTrue);

    await _tap(tester, _undo);
    expect(_calls(from), [('m1', 'Label_12', false), ('m1', 'Label_12', true)]);
    expect(find.byTooltip('Togli Etichetta Viaggi'), findsOneWidget);
  });

  _onMac('«Crea» makes the nested Etichetta and puts it on every message; refused names say why', (tester) async {
    await _start(tester);
    await _tap(tester, _row('m2'));
    await _tap(tester, _button);

    // Empty: Enter in the field.
    await tester.tap(_field);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    expect(find.text("Scrivi un nome per l'Etichetta."), findsOneWidget);

    await tester.enterText(_field, 'Progetti/');
    await _settle(tester);
    expect(find.text('Crea «Progetti/»'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('label-create')));
    expect(find.textContaining('Ogni livello ha bisogno di un nome'), findsOneWidget);

    // An existing Etichetta, other case: no «Crea» (Enter ticks it), so a duplicate is never created.
    await tester.enterText(_field, 'viaggi');
    await _settle(tester);
    expect(find.byKey(const ValueKey('label-create')), findsNothing);

    final from = gmail.labelCalls.length;
    await tester.enterText(_field, 'Progetti/Postino');
    await _settle(tester);
    await _tap(tester, find.byKey(const ValueKey('label-create')));
    final created = gmail.labels.singleWhere((l) => l.name == 'Progetti/Postino');
    expect(_calls(from), unorderedEquals([('m1', created.id, true), ('m2', created.id, true)]));
    expect(_ticked(tester, 'Progetti/Postino'), isTrue);
    expect(_snackbar, findsNothing);
  });

  _onMac('the × of a chip takes the Etichetta off the whole Conversazione, with Annulla once', (tester) async {
    await _start(tester);
    await _tap(tester, _row('m2'));
    final from = gmail.labelCalls.length;

    await _tap(tester, find.byTooltip('Togli Etichetta Viaggi'));
    expect(_calls(from), [('m1', 'Label_12', false)]);
    expect(find.byTooltip('Togli Etichetta Viaggi'), findsNothing);
    expect(_snackbar, findsOneWidget);

    await _tap(tester, _undo);
    expect(_calls(from).last, ('m1', 'Label_12', true));
    expect(find.byTooltip('Togli Etichetta Viaggi'), findsOneWidget);
  });

  _onMac('l opens the picker on the open Conversazione; Esc gives the focus back to the button', (tester) async {
    await _start(tester);
    await _tap(tester, _row('m2'));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await _settle(tester);
    expect(find.byType(PostinoLabelPicker), findsOneWidget);
    // The search field takes the focus: an l typed there is a letter, no second picker.
    expect(tester.testTextInput.isVisible, isTrue);

    await _escape(tester);
    expect(find.byType(PostinoLabelPicker), findsNothing);
    expect(_buttonFocus(tester).hasPrimaryFocus, isTrue);
  });

  testWidgets('l is ignored in a text field', (tester) async {
    var opened = 0;
    final cursor = ListCursor()..labels = () => opened++;
    final field = FocusNode();
    final other = FocusNode();
    addTearDown(field.dispose);
    addTearDown(other.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: PostaShortcuts(
            cursor: cursor,
            child: Column(
              children: [
                TextField(focusNode: field),
                Focus(focusNode: other, child: const SizedBox(height: 10)),
              ],
            ),
          ),
        ),
      ),
    );
    field.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    expect(opened, 0);
    other.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    expect(opened, 1);
  });

  _onMac('«Etichette…» in the context menu of a row opens the picker on that row\'s Conversazione', (tester) async {
    await _start(tester);
    // Another Conversazione open beside the list: the row's own is the one labelled, and one snackbar shows.
    await _tap(tester, _row('m2'));

    await tester.tap(_row('o1'), buttons: kSecondaryButton);
    await _settle(tester);
    await _tap(tester, find.byKey(const ValueKey('row-labels-a1-o1')));
    expect(find.byType(PostinoLabelPicker), findsOneWidget);
    expect(_ticked(tester, 'Viaggi'), isTrue);

    final from = gmail.labelCalls.length;
    await _tap(tester, _tile('Viaggi'));
    expect(_calls(from), [('o1', 'Label_12', false)]);
    expect(_snackbar, findsOneWidget);
    await _escape(tester);
    // The focus back on the row.
    expect(tester.widget<PostinoMessageTile>(_row('o1')).focusNode!.hasPrimaryFocus, isTrue);

    // From the keyboard: the menu key, then Enter on «Etichette…».
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(find.byType(PostinoLabelPicker), findsOneWidget);
    await _escape(tester);

    // Shift+F10.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await _settle(tester);
    expect(find.byKey(const ValueKey('row-labels-a1-o1')), findsOneWidget);
    await _escape(tester);
  });

  _onMac('«Etichette…» is a custom action of the row for the screen reader', (tester) async {
    await _start(tester);
    final action = CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: 'Etichette…'));
    final node = find.semantics
        .byPredicate((n) => n.getSemanticsData().customSemanticsActionIds?.contains(action) ?? false)
        .evaluate()
        .first;
    node.owner!.performAction(node.id, SemanticsAction.customAction, action);
    await _settle(tester);
    expect(find.byType(PostinoLabelPicker), findsOneWidget);
  });

  _onMac('the rows show their user Etichette as chips', (tester) async {
    await _start(tester);
    await _settle(tester);
    expect(tester.widget<PostinoMessageTile>(_row('o1')).labels, ['Viaggi']);
    // An Etichetta on an older message stands for the whole Conversazione.
    expect(tester.widget<PostinoMessageTile>(_row('m2')).labels, ['Viaggi']);
  });
}
