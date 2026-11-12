// PostinoSuggestions (#216): under its field, never focusable, text 200% without overflow, WCAG AA contrast.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

const _items = [
  (name: 'Bruno Bianchi della Valle Superiore', address: 'bruno.bianchi.dellavalle@example.com'),
  (name: null, address: 'ada@example.com'),
  (name: 'Maria Rossi', address: 'maria@example.com'),
];

Widget _app({double scale = 1, ThemeData? theme, int highlighted = 0, ValueChanged<int>? onSelected}) => MaterialApp(
  theme: theme ?? PostinoTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: PostinoSuggestions(
            suggestions: _items,
            highlighted: highlighted,
            onSelected: onSelected ?? (_) {},
            onDismiss: () {},
            countLabel: '3 suggerimenti',
            child: PostinoComposerField(label: 'A', controller: TextEditingController()),
          ),
        ),
      ),
    ),
  ),
);

double _contrast(Color a, Color b) {
  final (l1, l2) = (a.computeLuminance(), b.computeLuminance());
  return (l1 > l2 ? l1 + 0.05 : l2 + 0.05) / (l1 > l2 ? l2 + 0.05 : l1 + 0.05);
}

void main() {
  testWidgets('the panel hangs under the field, as wide, and a tap chooses without taking the focus', (tester) async {
    int? chosen;
    await tester.pumpWidget(_app(onSelected: (i) => chosen = i));
    await tester.pump();
    final field = tester.getRect(find.byType(PostinoComposerField));
    final panel = tester.getRect(find.byType(Material).last);
    expect(panel.top, moreOrLessEquals(field.bottom));
    expect(panel.width, field.width);

    await tester.tap(find.text('Maria Rossi'));
    expect(chosen, 2);
    expect(FocusManager.instance.primaryFocus?.context?.widget, isNot(isA<GestureDetector>()));
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

  test('ink and ink-muted reach WCAG AA (4.5:1) on the panel and on the highlighted row, light and dark', () {
    for (final theme in [PostinoTheme.light(), PostinoTheme.dark()]) {
      final c = theme.extension<PostinoColors>()!;
      for (final bg in [c.surfaceRaised, c.surfaceSelected]) {
        for (final fg in [c.ink, c.inkMuted]) {
          expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '${theme.brightness} $fg on $bg');
        }
      }
    }
  });
}
