// PostinoSuggestions (#216): under its field, never focusable, text 200% without overflow (contrast: contrast_test).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

const _items = [
  (name: 'Bruno Bianchi della Valle Superiore', address: 'bruno.bianchi.dellavalle@example.com'),
  (name: null, address: 'ada@example.com'),
  (name: 'Maria Rossi', address: 'maria@example.com'),
];

final _focus = FocusNode();

Widget _app({
  Alignment at = Alignment.topCenter,
  double scale = 1,
  ThemeData? theme,
  int highlighted = 0,
  ValueChanged<int>? onSelected,
}) => MaterialApp(
  theme: theme ?? PostinoTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: Scaffold(
        body: Align(
          alignment: at,
          child: PostinoSuggestions(
            suggestions: _items,
            highlighted: highlighted,
            onSelected: onSelected ?? (_) {},
            onDismiss: () {},
            countLabel: '3 suggerimenti',
            child: PostinoComposerField(label: 'A', controller: TextEditingController(), focusNode: _focus),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('the panel hangs under the field, as wide, and a tap chooses without taking the focus', (tester) async {
    int? chosen;
    await tester.pumpWidget(_app(onSelected: (i) => chosen = i));
    await tester.pump();
    final field = tester.getRect(find.byType(PostinoComposerField));
    final panel = tester.getRect(find.byType(Material).last);
    expect(panel.top, moreOrLessEquals(field.bottom));
    expect(panel.width, field.width);

    _focus.requestFocus();
    await tester.pump();
    await tester.tap(find.text('Maria Rossi'));
    await tester.pump();
    expect(chosen, 2);
    expect(_focus.hasFocus, isTrue);
  });

  testWidgets('each suggestion is one node «Name, address»; the highlighted one is selected', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(highlighted: 1));
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel('ada@example.com')),
      isSemantics(isButton: true, isSelected: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Maria Rossi, maria@example.com')),
      isSemantics(isButton: true, isSelected: false),
    );
    semantics.dispose();
  });

  testWidgets('with the keyboard open the panel stops above it and scrolls', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 640)
      ..devicePixelRatio = 1
      ..viewInsets = const FakeViewPadding(bottom: 480);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(tester.getRect(find.byType(Material).last).bottom, lessThanOrEqualTo(640 - 480));
    expect(tester.takeException(), isNull);
  });

  testWidgets('with little room under the field and the keyboard open the panel opens above it', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 640)
      ..devicePixelRatio = 1
      ..viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    // The field just above the keyboard, as Ccn on a phone.
    await tester.pumpWidget(_app(at: Alignment.bottomCenter));
    await tester.pump();
    final field = tester.getRect(find.byType(PostinoComposerField));
    final panel = tester.getRect(find.byType(Material).last);
    expect(panel.bottom, lessThanOrEqualTo(field.top));
    expect(panel.top, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('when the composer scrolls the panel follows the field and moves above it near the keyboard', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 640)
      ..devicePixelRatio = 1
      ..viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: PostinoTheme.light(),
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              const SizedBox(height: 260),
              PostinoSuggestions(
                suggestions: _items,
                highlighted: 0,
                onSelected: (_) {},
                onDismiss: () {},
                countLabel: '3 suggerimenti',
                child: PostinoComposerField(label: 'Ccn', controller: TextEditingController()),
              ),
              const SizedBox(height: 600),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    Rect field() => tester.getRect(find.byType(PostinoComposerField));
    Rect panel() => tester.getRect(find.byType(Material).last);
    // Just above the keyboard (340 px of window left): the panel opens above.
    expect(panel().bottom, moreOrLessEquals(field().top));
    scroll.jumpTo(250);
    await tester.pump();
    // Near the top now: it follows the field and goes under it.
    expect(panel().top, moreOrLessEquals(field().bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('at text 200% on a phone the rows grow and nothing overflows', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(scale: 2));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('maria@example.com', skipOffstage: false), findsOneWidget);
  });
}
