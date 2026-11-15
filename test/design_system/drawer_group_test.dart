// A drawer group (#311), an Account with its children: the Account's row is a button that opens and closes it,
// announced expanded or collapsed; closed, its children are gone (no Tab, no screen reader), an unread dot stands in
// for them and the highlight of an active child moves to the row; in the 72 rail the row is its 48×48 mark.
import 'dart:ui' show Tristate;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

const _address = 'ada@lavoro.it';
const _name = 'Account ada@lavoro.it';

Widget _drawer({
  required bool expanded,
  required VoidCallback onToggle,
  bool unread = false,
  bool active = false,
  bool rail = false,
}) => MaterialApp(
  // The icon rail is 72 wide, as PostinoAdaptiveLayout docks it.
  theme: rail
      ? PostinoTheme.light().copyWith(drawerTheme: const DrawerThemeData(width: PostinoSize.sidebarCollapsedWidth))
      : PostinoTheme.light(),
  home: Scaffold(
    body: PostinoSidebarScope(
      collapsed: rail,
      toggleLabel: 'Barra',
      toggle: () {},
      child: PostinoNavigationDrawer(
        sections: [
          PostinoDrawerSection(
            items: [PostinoDrawerItem(label: 'Lavoro', onTap: () {})],
          ),
          PostinoDrawerSection(
            title: 'Account',
            items: [
              PostinoDrawerItem(
                key: const ValueKey('group'),
                label: _address,
                semanticLabel: _name,
                account: (color: PostinoAccountColor.values.first, initial: 'A'),
                expanded: expanded,
                onTap: onToggle,
                children: [
                  PostinoDrawerItem(
                    label: 'Viaggi',
                    active: active,
                    unreadLabel: unread ? 'Non letto' : null,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);

/// A drawer whose group opens and closes on its own; returns the states it was toggled to.
Future<List<bool>> _pumpLive(WidgetTester tester, {bool unread = false, bool active = false}) async {
  final toggles = <bool>[];
  var expanded = true;
  await tester.pumpWidget(
    StatefulBuilder(
      builder: (context, setState) => _drawer(
        expanded: expanded,
        unread: unread,
        active: active,
        onToggle: () => setState(() => toggles.add(expanded = !expanded)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return toggles;
}

Finder get _row => find.byKey(const ValueKey('group'));

void main() {
  testWidgets('open: the row shows the address and the children are there', (tester) async {
    await _pumpLive(tester);
    expect(find.text(_address), findsOneWidget);
    expect(find.text('Viaggi'), findsOneWidget);
    expect(tester.getSize(_row).height, greaterThanOrEqualTo(48));
  });

  testWidgets('tapping the row closes the section: its items leave the tree, then it opens again', (tester) async {
    final toggles = await _pumpLive(tester);
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(toggles, [false]);
    expect(find.text('Viaggi'), findsNothing);
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(find.text('Viaggi'), findsOneWidget);
  });

  testWidgets('the row is a button announced expanded or collapsed, named after the Account', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpLive(tester);
    expect(
      tester.getSemantics(_row),
      matchesSemantics(
        label: _name,
        isButton: true,
        hasSelectedState: true,
        hasExpandedState: true,
        isExpanded: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(_row),
      matchesSemantics(
        label: _name,
        isButton: true,
        hasSelectedState: true,
        hasExpandedState: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('closing hides the items from the screen reader and from Tab while they leave', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpLive(tester);
    await tester.tap(_row);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Still drawn on its way out, but not readable nor focusable.
    expect(find.text('Viaggi'), findsOneWidget);
    final viaggi = find.text('Viaggi');
    expect(
      tester
          .widgetList<ExcludeSemantics>(find.ancestor(of: viaggi, matching: find.byType(ExcludeSemantics)))
          .any((e) => e.excluding),
      isTrue,
    );
    expect(
      tester
          .widgetList<ExcludeFocus>(find.ancestor(of: viaggi, matching: find.byType(ExcludeFocus)))
          .any((e) => e.excluding),
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('Enter and Space on the focused row toggle it', (tester) async {
    final toggles = await _pumpLive(tester);
    bool onHeader() {
      final focused = FocusManager.instance.primaryFocus?.context;
      return focused != null &&
          find.descendant(of: _row, matching: find.byElementPredicate((e) => e == focused)).evaluate().isNotEmpty;
    }

    for (var i = 0; i < 10 && !onHeader(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(onHeader(), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(toggles, [false, true]);
  });

  testWidgets('closed with an unread item: the dot shows and is read with the row; none when open', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpLive(tester, unread: true);
    expect(find.descendant(of: _row, matching: find.byKey(const ValueKey('unread-dot'))), findsNothing);
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(find.descendant(of: _row, matching: find.byKey(const ValueKey('unread-dot'))), findsOneWidget);
    expect(tester.getSemantics(_row).label, '$_name, Non letto');
    semantics.dispose();
  });

  testWidgets('closed without unread: no dot', (tester) async {
    await _pumpLive(tester);
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
  });

  testWidgets('closing the section of the active item moves the highlight to the row', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpLive(tester, active: true);
    final theme = PostinoTheme.light();
    final color = theme.extension<PostinoColors>()!.drawerItemBgActive;
    final box = find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == color,
    );
    expect(tester.getRect(box), tester.getRect(find.ancestor(of: find.text('Viaggi'), matching: find.byType(InkWell))));
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(tester.getRect(box), tester.getRect(_row));
    expect(tester.getSemantics(_row).flagsCollection.isSelected, Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('rail: a 48×48 mark with the address as tooltip, no text; the icons below when open', (tester) async {
    var expanded = true;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) =>
            _drawer(rail: true, unread: true, expanded: expanded, onToggle: () => setState(() => expanded = !expanded)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(_row), const Size(48, 48));
    expect(find.text(_address), findsNothing);
    expect(find.byTooltip(_address), findsOneWidget);
    expect(find.byTooltip('Viaggi'), findsOneWidget);
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Viaggi'), findsNothing);
    expect(find.descendant(of: _row, matching: find.byKey(const ValueKey('unread-dot'))), findsOneWidget);
  });

  testWidgets('the box follows the active row while a group above it closes and opens', (tester) async {
    // One theme: a new one at each rebuild would lerp the box's color.
    final theme = PostinoTheme.light();
    var expanded = true;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          theme: theme,
          home: Scaffold(
            body: PostinoNavigationDrawer(
              sections: [
                PostinoDrawerSection(
                  items: [
                    PostinoDrawerItem(
                      key: const ValueKey('first'),
                      label: 'a1@x.it',
                      expanded: expanded,
                      onTap: () => setState(() => expanded = !expanded),
                      children: [
                        for (final n in ['A', 'B', 'C']) PostinoDrawerItem(label: n, onTap: () {}),
                      ],
                    ),
                    PostinoDrawerItem(
                      label: 'a2@x.it',
                      onTap: () {},
                      children: [
                        PostinoDrawerItem(key: const ValueKey('active'), label: 'D', active: true, onTap: () {}),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final color = theme.extension<PostinoColors>()!.drawerItemBgActive;
    final box = find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == color,
    );
    final active = find.byKey(const ValueKey('active'));
    expect(tester.getRect(box), tester.getRect(active));
    // Mid-way, a frame after the row moved, the box is on it again; and at the end.
    for (final _ in [1, 2]) {
      await tester.tap(find.byKey(const ValueKey('first')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        expect(tester.getRect(box), tester.getRect(active));
      }
      await tester.pumpAndSettle();
      expect(tester.getRect(box), tester.getRect(active));
    }
  });

  testWidgets('swapping an open and a closed group keeps each its own state and children', (tester) async {
    final theme = PostinoTheme.light();
    var swapped = false;
    PostinoDrawerItem group(String id, {required bool expanded}) => PostinoDrawerItem(
      key: ValueKey(id),
      label: id,
      expanded: expanded,
      onTap: () {},
      children: [PostinoDrawerItem(key: ValueKey('$id-child'), label: '$id child', onTap: () {})],
    );
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                TextButton(onPressed: () => setState(() => swapped = !swapped), child: const Text('swap')),
                Expanded(
                  child: PostinoNavigationDrawer(
                    sections: [
                      PostinoDrawerSection(
                        items: [
                          for (final id in swapped ? ['B', 'A'] : ['A', 'B']) group(id, expanded: id == 'A'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('swap'));
    await tester.pump();
    // The open group stays open: its reveal moved with it, it does not open again from closed.
    final reveal = tester.widget<SizeTransition>(
      find.ancestor(of: find.text('A child'), matching: find.byType(SizeTransition)).first,
    );
    expect(reveal.sizeFactor.value, 1);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('A child'), findsOneWidget);
    expect(find.text('B child'), findsNothing);
    expect(
      tester.getTopLeft(find.text('A child')).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('A'))).dy),
    );
  });
}
