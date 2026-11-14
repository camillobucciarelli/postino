// A row of the list changes state (letto/non letto, Stella, selezione) with a short fade, not a jump (#282).
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

Widget _tile({required bool unread, bool starred = false, bool selected = false, bool reduced = false}) => MaterialApp(
  theme: PostinoTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: Scaffold(
        body: PostinoMessageTile(
          sender: 'Ada Okafor',
          subject: 'Contratto',
          preview: 'Il PDF firmato',
          time: '09:42',
          unread: unread,
          starred: starred,
          selected: selected,
          semanticLabel: 'Ada Okafor',
        ),
      ),
    ),
  ),
);

/// The opacity of each copy of the sender: two while the old look fades into the new.
List<double> _senders(WidgetTester tester) => [
  for (final e in find.text('Ada Okafor').evaluate())
    e.findAncestorWidgetOfExactType<FadeTransition>()?.opacity.value ?? 1,
];

/// What the row's background paints right now (the animated colour, not its target).
Finder get _paint => find.descendant(of: find.byType(AnimatedContainer), matching: find.byType(DecoratedBox)).first;

Color? _background(WidgetTester tester) => (tester.widget<DecoratedBox>(_paint).decoration as BoxDecoration).color;

void main() {
  testWidgets('read ↔ unread and the Stella fade from one look to the other', (tester) async {
    await tester.pumpWidget(_tile(unread: true));
    expect(_senders(tester), [1]);

    await tester.pumpWidget(_tile(unread: false));
    await tester.pump(PostinoMotion.toggle ~/ 2);
    final mid = _senders(tester);
    expect(mid, hasLength(2));
    expect(mid, everyElement(inExclusiveRange(0, 1)));
    expect(find.byKey(const ValueKey('unread')), findsOneWidget, reason: 'the dot fades out with the old look');

    await tester.pumpAndSettle();
    expect(_senders(tester), [1]);
    expect(find.byKey(const ValueKey('unread')), findsNothing);

    await tester.pumpWidget(_tile(unread: false, starred: true));
    await tester.pump(PostinoMotion.toggle ~/ 2);
    expect(_senders(tester), hasLength(2));
    await tester.pumpAndSettle();
    expect(_senders(tester), [1]);
  });

  testWidgets('the selection colours the row gradually', (tester) async {
    await tester.pumpWidget(_tile(unread: false));
    final from = _background(tester);
    await tester.pumpWidget(_tile(unread: false, selected: true));
    await tester.pump(PostinoMotion.state ~/ 2);
    final mid = _background(tester);
    await tester.pumpAndSettle();
    final to = _background(tester);
    expect(to, isNot(from));
    expect(mid, isNot(anyOf(from, to)));
  });

  testWidgets('with reduced motion the row changes at once', (tester) async {
    await tester.pumpWidget(_tile(unread: true, reduced: true));
    await tester.pumpWidget(_tile(unread: false, selected: true, reduced: true));
    await tester.pump();
    expect(_senders(tester), [1]);
    expect(find.byKey(const ValueKey('unread')), findsNothing);
    expect(tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).duration, Duration.zero);
  });
}
