// PostinoActionBar (#369): the Azioni of a detail in groups, an overflow by priority into «Altre azioni», the primary
// action filled (with its label where the bottom bar has room), the bottom bar clear of the gesture bar and the
// snackbars above it (postino_snackbar_lift_test.dart).
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

void _noop() {}

PostinoBarAction _a(String label, {int? overflow, bool primary = false, bool selected = false, String? shortcut}) =>
    PostinoBarAction(
      key: ValueKey(label),
      icon: PostinoIcons.star,
      label: label,
      onPressed: _noop,
      overflow: overflow,
      primary: primary,
      selected: selected,
      shortcut: shortcut,
    );

/// The layout of the wide Conversazione: Archivia · Elimina | Stella · Letto · Etichette | Inoltra · Rispondi a tutti
/// · Rispondi; out first Etichette, then Letto, Stella, Inoltra, Rispondi a tutti.
List<List<PostinoBarAction>> get _wide => [
  [_a('Archivia'), _a('Elimina')],
  [_a('Stella', overflow: 2), _a('Letto', overflow: 1), _a('Etichette', overflow: 0)],
  [_a('Inoltra', overflow: 3), _a('Rispondi a tutti', overflow: 4), _a('Rispondi', primary: true)],
];

List<List<PostinoBarAction>> get _bottom => [
  [_a('Archivia'), _a('Elimina')],
  [_a('Inoltra'), _a('Rispondi a tutti'), _a('Rispondi', primary: true, shortcut: 'R')],
];

Future<void> _pump(
  WidgetTester tester,
  Widget bar, {
  double width = 1200,
  double scale = 1,
  EdgeInsets viewPadding = EdgeInsets.zero,
  bool atBottom = false,
}) async {
  tester.view
    ..physicalSize = Size(width, 800)
    ..devicePixelRatio = 1
    ..viewPadding = FakeViewPadding(bottom: viewPadding.bottom)
    ..padding = FakeViewPadding(bottom: viewPadding.bottom);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: PostinoTheme.light(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: PostinoSnackbarHost(
            child: Align(alignment: atBottom ? Alignment.bottomCenter : Alignment.topLeft, child: bar),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The labels of the actions on the bar, in order, and of those in its «more» menu.
List<String> _onBar(WidgetTester tester) => [
  for (final label in [
    'Archivia',
    'Elimina',
    'Stella',
    'Letto',
    'Etichette',
    'Inoltra',
    'Rispondi a tutti',
    'Rispondi',
  ])
    if (find.byKey(ValueKey(label)).evaluate().isNotEmpty) label,
];

Future<List<String>> _inMenu(WidgetTester tester) async {
  if (find.byTooltip('Altre azioni').evaluate().isEmpty) return [];
  await tester.tap(find.byTooltip('Altre azioni'));
  await tester.pumpAndSettle();
  final items = [
    for (final e in find.byType(MenuItemButton).evaluate()) ((e.widget as MenuItemButton).child! as Text).data!,
  ];
  await tester.tapAt(Offset.zero);
  await tester.pumpAndSettle();
  return items;
}

void main() {
  group('overflow by priority', () {
    testWidgets('with room every action is on the bar, no menu', (tester) async {
      await _pump(tester, PostinoActionBar(groups: _wide, moreLabel: 'Altre azioni'));
      expect(_onBar(tester), hasLength(8));
      expect(find.byTooltip('Altre azioni'), findsNothing);
    });

    // 8 buttons and two dividers want 384 + 34 = 418. Narrower, the «more» button takes a slot: Etichette leaves
    // with Letto (Stella stays), then Stella, then Inoltra and Rispondi a tutti.
    for (final (width, menu) in [
      (440.0, <String>[]),
      (410.0, ['Letto', 'Etichette']),
      (360.0, ['Stella', 'Letto', 'Etichette']),
      (300.0, ['Stella', 'Letto', 'Etichette', 'Inoltra']),
      (240.0, ['Stella', 'Letto', 'Etichette', 'Inoltra', 'Rispondi a tutti']),
    ]) {
      testWidgets('at $width the menu holds $menu, in the bar\'s order; Rispondi, Archivia, Elimina never', (
        tester,
      ) async {
        await _pump(
          tester,
          SizedBox(
            width: width,
            child: PostinoActionBar(groups: _wide, moreLabel: 'Altre azioni'),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(_onBar(tester), containsAll(['Archivia', 'Elimina', 'Rispondi']));
        expect(await _inMenu(tester), menu);
        for (final label in menu) {
          expect(find.byKey(ValueKey(label)), findsNothing, reason: label);
        }
      });
    }

    testWidgets('narrower still, the dividers give way before the actions that stay overflow', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 200,
          child: PostinoActionBar(groups: _wide, moreLabel: 'Altre azioni'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_onBar(tester), ['Archivia', 'Elimina', 'Rispondi']);
    });
  });

  testWidgets('a pane too narrow for the actions that stay: Elimina, then Archivia, go into the menu as a last '
      'resort; Rispondi never; nothing overflows', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: 120,
        child: PostinoActionBar(groups: _wide, moreLabel: 'Altre azioni'),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(_onBar(tester), ['Rispondi']);
    expect(await _inMenu(tester), [
      'Archivia',
      'Elimina',
      'Stella',
      'Letto',
      'Etichette',
      'Inoltra',
      'Rispondi a tutti',
    ]);
  });

  testWidgets('alignEnd: the groups sit at the end of the bar (beside a back arrow)', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: 400,
        child: PostinoActionBar(
          moreLabel: 'Altre azioni',
          alignEnd: true,
          groups: [
            [_a('Stella', overflow: 2), _a('Letto', overflow: 1), _a('Etichette', overflow: 0)],
          ],
        ),
      ),
    );
    expect(tester.getRect(find.byKey(const ValueKey('Etichette'))).right, 400);
    expect(tester.getRect(find.byKey(const ValueKey('Stella'))).left, 400 - 3 * 48);
  });

  group('Stella', () {
    testWidgets('on: filled in the accent; off: the outline in ink-muted; the label says what a tap does', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        PostinoActionBar(
          moreLabel: 'Altre azioni',
          groups: [
            [_a('Togli Stella', selected: true, shortcut: 'S'), _a('Aggiungi Stella', shortcut: 'S')],
          ],
        ),
      );
      const c = PostinoColors.light;
      PostinoIcon icon(String label) => tester.widget<PostinoIcon>(
        find.descendant(of: find.byKey(ValueKey(label)), matching: find.byType(PostinoIcon)),
      );
      Color? color(String label) => tester
          .widget<IconButton>(find.descendant(of: find.byKey(ValueKey(label)), matching: find.byType(IconButton)))
          .color;
      expect(icon('Togli Stella').filled, isTrue);
      expect(color('Togli Stella'), c.star);
      expect(icon('Aggiungi Stella').filled, isFalse);
      expect(color('Aggiungi Stella'), c.inkMuted);
      expect(find.bySemanticsLabel('Togli Stella'), findsOneWidget);
      expect(find.bySemanticsLabel('Aggiungi Stella'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('bottom bar', () {
    Widget bottom() =>
        PostinoActionBar(groups: _bottom, moreLabel: 'Altre azioni', placement: PostinoActionBarPlacement.bottom);

    for (final (width, extended) in [(390.0, true), (360.0, true), (359.0, false), (320.0, false)]) {
      testWidgets('at $width Rispondi is ${extended ? 'icon and text' : 'the icon only'}, filled', (tester) async {
        await _pump(tester, bottom(), width: width, atBottom: true);
        final reply = find.byKey(const ValueKey('Rispondi'));
        expect(find.descendant(of: reply, matching: find.text('Rispondi')), extended ? findsOneWidget : findsNothing);
        expect(find.descendant(of: reply, matching: find.byType(PostinoIcon)), findsOneWidget);
        expect(find.descendant(of: find.byKey(const ValueKey('Inoltra')), matching: find.byType(Text)), findsNothing);
      });
    }

    testWidgets('at 200% text a label that does not fit leaves the icon: nothing is cut', (tester) async {
      await _pump(tester, bottom(), width: 360, scale: 2, atBottom: true);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('Rispondi')), findsOneWidget);
    });

    testWidgets('Archivia and Elimina stand 8 apart; Rispondi at the end, the others before it', (tester) async {
      await _pump(tester, bottom(), width: 390, atBottom: true);
      final archive = tester.getRect(find.byKey(const ValueKey('Archivia')));
      final delete = tester.getRect(find.byKey(const ValueKey('Elimina')));
      expect(delete.left - archive.right, PostinoSpacing.s2);
      final forward = tester.getRect(find.byKey(const ValueKey('Inoltra')));
      final replyAll = tester.getRect(find.byKey(const ValueKey('Rispondi a tutti')));
      final reply = tester.getRect(find.byKey(const ValueKey('Rispondi')));
      expect(forward.left, greaterThan(delete.right + PostinoSpacing.s4));
      expect(replyAll.left, greaterThanOrEqualTo(forward.right));
      expect(reply.left, greaterThanOrEqualTo(replyAll.right));
      for (final r in [archive, delete, forward, replyAll]) {
        expect(r.shortestSide, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('clears the gesture bar: the buttons sit above viewPadding.bottom, the surface goes on under it', (
      tester,
    ) async {
      await _pump(tester, bottom(), width: 390, viewPadding: const EdgeInsets.only(bottom: 34), atBottom: true);
      final bar = tester.getRect(find.byType(PostinoActionBar));
      expect(bar.bottom, 800);
      final reply = tester.getRect(find.byKey(const ValueKey('Rispondi')));
      expect(reply.bottom, lessThanOrEqualTo(800 - 34));
    });
  });
}
