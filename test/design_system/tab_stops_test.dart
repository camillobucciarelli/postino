import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Widget _app(Widget child) => MaterialApp(
  theme: PostinoTheme.light(),
  home: Material(child: child),
);

void main() {
  testWidgets('Tab in a banner goes straight to the button, not to the text', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        PostinoBanner(
          tone: PostinoBannerTone.offline,
          title: 'Sei offline',
          message: 'Riprova più tardi.',
          actionLabel: 'Riprova',
          onAction: () {},
        ),
      ),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(
      find.descendant(
        of: find.byElementPredicate(
          (e) => e == FocusManager.instance.primaryFocus?.context,
        ),
        matching: find.text('Riprova'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Tab in an empty state does not stop on the text', (t) async {
    await t.pumpWidget(
      _app(const PostinoEmptyState(title: 'Niente di nuovo', body: 'Qui.')),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
  });

  testWidgets(
    'a control scrolled under the AppBar does not win over the back button',
    (t) async {
      final scroll = ScrollController();
      t.view.physicalSize = const Size(1200, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(
          PostinoListDetailLayout(
            list: const SizedBox(),
            empty: const SizedBox(),
            onClose: () {},
            detailKey: 1,
            resizeLabel: 'Larghezza',
            resizeValueLabel: (w) => '$w',
            detail: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {},
                ),
              ),
              body: ListView(
                controller: scroll,
                children: [
                  for (var i = 0; i < 20; i++)
                    SizedBox(
                      height: 40,
                      child: TextButton(
                        onPressed: () {},
                        child: Text('Voce $i'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      // Item 0 ends up at y 2..42: positive top, above the viewport (it starts at 56), under the bar.
      scroll.jumpTo(54);
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(find.text('Voce 0', skipOffstage: false)).dy,
        greaterThan(0),
      );
      // Narrow window: the detail opens as a full page.
      t.view.physicalSize = const Size(600, 800);
      await t.pumpAndSettle();
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused, isNotNull);
      expect(
        find.descendant(
          of: find.byElementPredicate((e) => e == focused),
          matching: find.byIcon(Icons.arrow_back),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Tab walks the composer: sender, fields, editor, formats', (
    t,
  ) async {
    final editor = FocusNode(debugLabel: 'editor');
    addTearDown(editor.dispose);
    await t.pumpWidget(
      _app(
        PostinoComposerLayout(
          sender: PostinoSenderPicker(
            options: const [
              (
                id: 'a1',
                mark: (color: PostinoAccountColor.sky, initial: 'L'),
                address: 'lavoro@example.com',
              ),
            ],
            selectedId: 'a1',
            onSelected: (_) {},
            label: 'Da',
          ),
          fields: [
            PostinoComposerField(
              label: 'A',
              controller: TextEditingController(),
            ),
            PostinoComposerField(
              label: 'Oggetto',
              controller: TextEditingController(),
            ),
          ],
          editor: PostinoRichEditor(
            controller: QuillController.basic(),
            focusNode: editor,
            label: 'Corpo',
            placeholder: 'Scrivi',
            labels: const PostinoFormatLabels(
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
            ),
          ),
        ),
      ),
    );
    final stops = <Type>[];
    for (var i = 0; i < 12; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      final focused = FocusManager.instance.primaryFocus!;
      if (editor.hasFocus) break;
      final ctx = focused.context!;
      stops.add(
        [
          PostinoSenderPicker,
          PostinoComposerField,
          PostinoFormatButton,
        ].firstWhere(
          (type) => find
              .ancestor(
                of: find.byElementPredicate((e) => e == ctx),
                matching: find.byType(type),
              )
              .evaluate()
              .isNotEmpty,
        ),
      );
    }
    expect(editor.hasFocus, isTrue);
    expect(stops, [
      PostinoSenderPicker,
      PostinoComposerField,
      PostinoComposerField,
    ]);
    // The formats come after the editor (their shortcuts are the fast way): Tab leaves the editor for them.
    for (var i = 0; i < 7; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(
        find.ancestor(
          of: find.byElementPredicate(
            (e) => e == FocusManager.instance.primaryFocus!.context,
          ),
          matching: find.byType(PostinoFormatButton),
        ),
        findsOneWidget,
      );
    }
  });
}
