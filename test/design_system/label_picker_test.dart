import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/label_name.dart';
import 'package:postino/design_system/design_system.dart';

final _strings = PostinoLabelPickerStrings(
  search: 'Cerca o crea un’Etichetta',
  nestHelp: 'Usa «/» per annidarla.',
  create: (name) => 'Crea «$name»',
  selected: (n) => 'Etichette, $n ${n == 1 ? 'selezionata' : 'selezionate'}',
  empty: 'Nessuna Etichetta',
);

/// A Conversazione with its Etichette, the button «Etichette» that opens the picker in a popover.
class _Host() {
  final labels = ValueNotifier<List<PostinoLabelOption>>(const [
    (id: 'l1', name: 'Fatture'),
    (id: 'l2', name: 'Progetti'),
    (id: 'l3', name: 'Progetti/Postino'),
  ]);
  final selected = ValueNotifier<Set<String>>({'l1'});
  final created = <String>[];
  final button = FocusNode(debugLabel: 'Etichette');

  void toggle(String id) =>
      selected.value = selected.value.contains(id) ? ({...selected.value}..remove(id)) : {...selected.value, id};

  void create(String name) {
    created.add(name);
    final id = 'n${created.length}';
    labels.value = [...labels.value, (id: id, name: name)];
    selected.value = {...selected.value, id};
  }

  String? validate(String name) => switch (labelNameError(name, labels.value.map((l) => l.name))) {
    null => null,
    LabelNameError.empty => 'Scrivi un nome per l’Etichetta.',
    LabelNameError.emptyLevel => 'Ogni livello ha bisogno di un nome.',
    LabelNameError.duplicate => 'Esiste già.',
  };

  Widget picker() => ListenableBuilder(
    listenable: Listenable.merge([labels, selected]),
    builder: (context, _) => PostinoLabelPicker(
      labels: labels.value,
      selected: selected.value,
      onToggle: toggle,
      onCreate: create,
      validateName: validate,
      strings: _strings,
    ),
  );

  Widget app() => MaterialApp(
    theme: PostinoTheme.light(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topRight,
        child: Builder(
          builder: (context) => PostinoIconButton(
            icon: PostinoIcons.tag,
            label: 'Etichette',
            focusNode: button,
            onPressed: () => unawaited(
              showPostinoPopover<void>(
                context,
                label: 'Etichette',
                barrierLabel: 'Chiudi',
                returnFocus: button,
                builder: (_) => picker(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<_Host> _open(WidgetTester t, {Size size = const Size(1000, 800)}) async {
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final host = _Host();
  addTearDown(host.button.dispose);
  await t.pumpWidget(host.app());
  await t.tap(find.byTooltip('Etichette'));
  await t.pumpAndSettle();
  return host;
}

Finder get _field => find.descendant(of: find.byKey(const ValueKey('label-search')), matching: find.byType(TextField));

bool _focused(WidgetTester t, Finder f) {
  final node = FocusManager.instance.primaryFocus;
  return node?.context != null &&
      find.descendant(of: f, matching: find.byElementPredicate((e) => e == node!.context)).evaluate().isNotEmpty;
}

void main() {
  testWidgets('the search field takes the focus; typing filters, and offers Crea when not exact', (t) async {
    await _open(t);
    expect(_focused(t, _field), isTrue);
    expect(find.text('Fatture'), findsOneWidget);

    await t.enterText(_field, 'prog');
    await t.pump();
    expect(find.text('Fatture'), findsNothing);
    expect(find.text('Progetti'), findsOneWidget);
    expect(find.text('Progetti/Postino'), findsOneWidget);
    expect(find.text('Crea «prog»'), findsOneWidget);

    await t.enterText(_field, 'PROGETTI');
    await t.pump();
    expect(find.byKey(const ValueKey('label-create')), findsNothing);

    await t.enterText(_field, 'zzz');
    await t.pump();
    expect(find.text('Crea «zzz»'), findsOneWidget);
    expect(find.text('Nessuna Etichetta'), findsNothing);
  });

  testWidgets('a tick applies at once; Crea creates and assigns, then clears the field', (t) async {
    final host = await _open(t);
    await t.tap(find.text('Progetti'));
    await t.pump();
    expect(host.selected.value, {'l1', 'l2'});
    await t.tap(find.text('Fatture'));
    await t.pump();
    expect(host.selected.value, {'l2'});

    await t.enterText(_field, '  Viaggi ');
    await t.pump();
    await t.tap(find.text('Crea «Viaggi»'));
    await t.pump();
    expect(host.created, ['Viaggi']);
    expect(host.selected.value, contains('n1'));
    expect(find.text('Viaggi'), findsOneWidget);
    expect(t.widget<TextField>(_field).controller!.text, isEmpty);
  });

  testWidgets('Enter in the field ticks the exact match, or creates a nested one', (t) async {
    final host = await _open(t);
    await t.enterText(_field, 'progetti');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(host.selected.value, {'l1', 'l2'});
    expect(host.created, isEmpty);

    await t.enterText(_field, 'Progetti/Casa');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(host.created, ['Progetti/Casa']);
  });

  testWidgets('an invalid name is refused with an error in a live region, cleared by typing', (t) async {
    final semantics = t.ensureSemantics();
    final host = await _open(t);
    for (final (text, error) in [
      ('', 'Scrivi un nome per l’Etichetta.'),
      ('Progetti/', 'Ogni livello ha bisogno di un nome.'),
    ]) {
      await t.enterText(_field, text);
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      expect(find.text(error), findsOneWidget);
      expect(t.getSemantics(find.text(error)), isSemantics(label: error, isLiveRegion: true));
    }
    expect(host.created, isEmpty);
    await t.enterText(_field, 'Progetti/X');
    await t.pump();
    expect(find.text('Ogni livello ha bisogno di un nome.'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the count of the selected is a live region; each row exposes checked', (t) async {
    final semantics = t.ensureSemantics();
    final host = await _open(t);
    expect(
      find.semantics.byPredicate((n) => n.label == 'Etichette, 1 selezionata' && n.flagsCollection.isLiveRegion),
      findsOne,
    );
    expect(t.getSemantics(find.text('Fatture')), isSemantics(label: 'Fatture', hasCheckedState: true, isChecked: true));
    expect(t.getSemantics(find.text('Progetti')), isSemantics(hasCheckedState: true, isChecked: false));
    host.toggle('l2');
    await t.pump();
    expect(find.semantics.byLabel('Etichette, 2 selezionate'), findsOne);
    expect(t.getSemantics(find.text('Progetti')), isSemantics(isChecked: true));
    semantics.dispose();
  });

  testWidgets('keyboard: Tab to the list, Up/Down between rows, Space/Enter tick, Esc gives the focus back', (t) async {
    final host = await _open(t);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(_focused(t, find.byKey(const ValueKey('label-l1'))), isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    expect(_focused(t, find.byKey(const ValueKey('label-l2'))), isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(host.selected.value, {'l1', 'l2'});
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(host.selected.value, {'l1', 'l2', 'l3'});
    // Each row is one Tab stop: from the last row Up twice reaches the first.
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump();
    expect(_focused(t, find.byKey(const ValueKey('label-l1'))), isTrue);

    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(PostinoLabelPicker), findsNothing);
    expect(host.button.hasPrimaryFocus, isTrue);
  });

  testWidgets('under 600 wide the picker is a bottom sheet with the same content', (t) async {
    await _open(t, size: const Size(400, 800));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(PostinoLabelPicker), findsOneWidget);
    expect(find.text('Fatture'), findsOneWidget);
  });

  testWidgets('at least 600 wide it is a popover anchored under the button', (t) async {
    await _open(t);
    expect(find.byType(BottomSheet), findsNothing);
    final button = t.getRect(find.byTooltip('Etichette'));
    final panel = t.getRect(find.byType(PostinoLabelPicker));
    expect(panel.top, greaterThanOrEqualTo(button.bottom));
    expect(panel.right, lessThanOrEqualTo(button.right + 1));
  });
}
