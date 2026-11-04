import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Widget _app(Widget child) => MaterialApp(
  theme: PostinoTheme.light(),
  home: Scaffold(body: child),
);

bool _focusedIn(Finder f) {
  final node = FocusManager.instance.primaryFocus;
  return node?.context != null &&
      find.descendant(of: f, matching: find.byElementPredicate((e) => e == node!.context)).evaluate().isNotEmpty;
}

void main() {
  group('PostinoLabelChip with onRemove', () {
    testWidgets('the × is one Tab stop named «Togli Etichetta X», 48 square, and removes', (t) async {
      final semantics = t.ensureSemantics();
      var removed = 0;
      await t.pumpWidget(
        _app(
          Column(
            children: [
              PostinoLabelChip(name: 'Fatture', onRemove: () => removed++, removeLabel: 'Togli Etichetta Fatture'),
              PostinoButton(label: 'Dopo', onPressed: () {}),
            ],
          ),
        ),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('Togli Etichetta Fatture')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      expect(find.bySemanticsLabel('Fatture'), findsOneWidget);
      expect(
        t.getSize(find.descendant(of: find.byType(PostinoLabelChip), matching: find.byType(InkWell))),
        const Size.square(PostinoSize.touchTargetAndroid),
      );

      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(_focusedIn(find.byType(PostinoLabelChip)), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(removed, 1);
      // Only the ×: the next Tab leaves the chip.
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(_focusedIn(find.byType(PostinoButton)), isTrue);
      semantics.dispose();
    });

    testWidgets('without onRemove the chip is read-only, no Tab stop', (t) async {
      await t.pumpWidget(_app(const Center(child: PostinoLabelChip(name: 'Fatture'))));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('the Conversazione gives each chip its ×', (t) async {
      final removed = <String>[];
      await t.pumpWidget(
        _app(
          PostinoThreadView(
            subject: 'Fattura',
            account: (color: PostinoAccountColor.sky, initial: 'L'),
            accountName: 'lavoro@example.com',
            labels: const ['Fatture', 'Progetti'],
            onRemoveLabel: removed.add,
            removeLabelName: (l) => 'Togli Etichetta $l',
            messages: const [],
          ),
        ),
      );
      await t.tap(find.byTooltip('Togli Etichetta Progetti'));
      expect(removed, ['Progetti']);
    });
  });

  group('PostinoMessageTile labels', () {
    Widget tile({List<String> labels = const []}) => PostinoMessageTile(
      sender: 'Ada',
      subject: 'Fattura',
      preview: 'In allegato.',
      time: '09:42',
      unread: false,
      starred: false,
      labels: labels,
      semanticLabel: 'Ada',
    );

    testWidgets('chips under the preview; without labels the row keeps its height', (t) async {
      await t.pumpWidget(
        _app(
          Column(
            children: [
              tile(),
              tile(labels: const ['Fatture']),
            ],
          ),
        ),
      );
      final tiles = find.byType(PostinoMessageTile);
      expect(find.byKey(const ValueKey('labels')), findsOneWidget);
      expect(find.byType(PostinoLabelChip), findsOneWidget);
      expect(t.getSize(tiles.at(1)).height, greaterThan(t.getSize(tiles.first).height));
      expect(t.getSize(tiles.first).height, t.element(find.byType(Scaffold)).density.rowHeight);
    });
  });

  group('PostinoContextMenu', () {
    Future<List<String>> pump(WidgetTester t) async {
      final picked = <String>[];
      await t.pumpWidget(
        _app(
          Align(
            alignment: Alignment.topLeft,
            child: PostinoContextMenu(
              items: [
                PostinoMenuItem(label: 'Etichette…', onPressed: () => picked.add('etichette')),
                PostinoMenuItem(label: 'Archivia', onPressed: () => picked.add('archivia')),
              ],
              child: const PostinoMessageTile(
                sender: 'Ada',
                subject: 'Fattura',
                preview: 'In allegato.',
                time: '09:42',
                unread: false,
                starred: false,
                onTap: _noop,
                semanticLabel: 'Ada, Fattura',
              ),
            ),
          ),
        ),
      );
      return picked;
    }

    testWidgets('a right click opens it at the pointer, the first item focused', (t) async {
      final picked = await pump(t);
      await t.tap(find.text('Fattura'), buttons: kSecondaryButton);
      await t.pumpAndSettle();
      expect(find.text('Etichette…'), findsOneWidget);
      expect(_focusedIn(find.widgetWithText(MenuItemButton, 'Etichette…')), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(picked, ['etichette']);
    });

    testWidgets('a long press opens it too', (t) async {
      await pump(t);
      await t.longPress(find.text('Fattura'));
      await t.pumpAndSettle();
      expect(find.text('Archivia'), findsOneWidget);
    });

    for (final (name, keys) in [
      ('the menu key', [LogicalKeyboardKey.contextMenu]),
      ('Shift+F10', [LogicalKeyboardKey.shift, LogicalKeyboardKey.f10]),
    ]) {
      testWidgets('$name opens it from the focused row; Esc closes it', (t) async {
        await pump(t);
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        for (final k in keys) {
          await t.sendKeyDownEvent(k);
        }
        for (final k in keys.reversed) {
          await t.sendKeyUpEvent(k);
        }
        await t.pumpAndSettle();
        expect(find.text('Etichette…'), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.text('Etichette…'), findsNothing);
      });
    }

    testWidgets('the arrows inside the child stay the caller\'s (the list moves with them)', (t) async {
      var down = 0;
      await t.pumpWidget(
        _app(
          CallbackShortcuts(
            bindings: {const SingleActivator(LogicalKeyboardKey.arrowDown): () => down++},
            child: const PostinoContextMenu(
              items: [PostinoMenuItem(label: 'Etichette…', onPressed: _noop)],
              child: PostinoMessageTile(
                sender: 'Ada',
                subject: 'Fattura',
                preview: 'In allegato.',
                time: '09:42',
                unread: false,
                starred: false,
                onTap: _noop,
                semanticLabel: 'Ada, Fattura',
              ),
            ),
          ),
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(down, 1);
    });

    testWidgets('the items are custom actions of the row for the screen reader', (t) async {
      final semantics = t.ensureSemantics();
      final picked = await pump(t);
      // The row's node merges the actions of the menu: what the screen reader focuses.
      final node = find.semantics
          .byPredicate((n) => n.mergeAllDescendantsIntoThisNode && n.getSemanticsData().label == 'Ada, Fattura')
          .evaluate()
          .single;
      final action = CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: 'Etichette…'));
      expect(node.getSemanticsData().customSemanticsActionIds, contains(action));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.customAction, action);
      expect(picked, ['etichette']);
      semantics.dispose();
    });
  });

  group('showPostinoDialog', () {
    Future<Future<bool?>> open(WidgetTester t, {Size size = const Size(1000, 800)}) async {
      t.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      late Future<bool?> result;
      await t.pumpWidget(
        _app(
          Builder(
            builder: (context) => PostinoButton(
              label: 'Apri',
              onPressed: () => result = showPostinoDialog<bool>(
                context,
                title: 'Scaricare 310 MB su rete cellulare?',
                cancelValue: false,
                child: PostinoDialogActions(
                  children: [
                    PostinoButton(
                      label: 'Aspetta il Wi-Fi',
                      variant: PostinoButtonVariant.ghost,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    PostinoButton(
                      label: 'Scarica ora',
                      autofocus: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Apri'));
      await t.pumpAndSettle();
      return result;
    }

    testWidgets('the focus starts on the action given autofocus, Enter picks it', (t) async {
      final result = await open(t);
      expect(find.byType(Dialog), findsOneWidget);
      expect(_focusedIn(find.widgetWithText(FilledButton, 'Scarica ora')), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(await result, isTrue);
    });

    testWidgets('Esc answers the cancel value', (t) async {
      final result = await open(t);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(await result, isFalse);
    });

    testWidgets('under 600 wide it is a bottom sheet', (t) async {
      final result = await open(t, size: const Size(400, 800));
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Scarica ora'), findsOneWidget);
      await t.tapAt(const Offset(200, 20));
      await t.pumpAndSettle();
      expect(await result, isFalse);
    });
  });

  group('atoms', () {
    testWidgets('a switch on its own exposes toggled and its name', (t) async {
      final semantics = t.ensureSemantics();
      await t.pumpWidget(_app(PostinoSwitch(value: true, label: 'Fatture', onChanged: (_) {})));
      expect(
        t.getSemantics(find.byType(PostinoSwitch)),
        isSemantics(label: 'Fatture', hasToggledState: true, isToggled: true),
      );
      semantics.dispose();
    });

    testWidgets('the switch row is one control, toggled, named by the Etichetta', (t) async {
      final semantics = t.ensureSemantics();
      var value = false;
      await t.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) => PostinoSwitchRow(
              title: 'Fatture',
              description: 'Automatica',
              value: value,
              onChanged: (v) => set(() => value = v),
            ),
          ),
        ),
      );
      expect(
        t.getSemantics(find.byType(PostinoSwitchRow)),
        isSemantics(label: 'Fatture\nAutomatica', hasToggledState: true, isToggled: false),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(value, isTrue);
      semantics.dispose();
    });

    testWidgets('the progress bar speaks in steps of 25%', (t) async {
      final semantics = t.ensureSemantics();
      for (final (v, said) in [(0.1, '0%'), (0.54, '50%'), (0.99, '75%'), (1.0, '100%')]) {
        await t.pumpWidget(_app(PostinoProgressBar(label: 'Download', value: v)));
        expect(t.getSemantics(find.byType(PostinoProgressBar)), isSemantics(label: 'Download', value: said));
      }
      semantics.dispose();
    });

    testWidgets('the settings item is one button, the whole row tappable', (t) async {
      final semantics = t.ensureSemantics();
      var opened = 0;
      await t.pumpWidget(
        _app(PostinoSettingsItem(title: 'Etichette automatiche', subtitle: '2 attive', onTap: () => opened++)),
      );
      expect(
        t.getSemantics(find.byType(PostinoSettingsItem)),
        isSemantics(label: 'Etichette automatiche\n2 attive', isButton: true),
      );
      await t.tap(find.text('2 attive'));
      expect(opened, 1);
      semantics.dispose();
    });

    testWidgets('the text field is named by its label and helper; Enter with onSubmitted keeps the focus', (t) async {
      final semantics = t.ensureSemantics();
      final submitted = <String>[];
      await t.pumpWidget(
        _app(PostinoTextField(label: 'Descrizione', helper: 'Che email ci vanno', onSubmitted: submitted.add)),
      );
      expect(
        t.getSemantics(find.byType(TextField)),
        isSemantics(label: 'Descrizione\nChe email ci vanno', isTextField: true),
      );
      await t.enterText(find.byType(TextField), 'fatture');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      expect(submitted, ['fatture']);
      expect(_focusedIn(find.byType(TextField)), isTrue);
      semantics.dispose();
    });
  });
}

void _noop() {}
