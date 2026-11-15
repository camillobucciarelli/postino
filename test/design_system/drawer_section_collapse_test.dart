// A collapsible PostinoDrawerSection (#311): the header is a button that opens and closes it, announced expanded or
// collapsed; closed, its items are gone (no Tab, no screen reader), an unread dot stands in for them and the
// highlight of an active item moves to the header; in the 72 rail the header is a 48×48 chevron with a tooltip.
import 'dart:ui' show Tristate;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

const _title = 'Etichette di Lavoro';

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
            title: _title,
            account: (color: PostinoAccountColor.values.first, initial: 'L'),
            expanded: expanded,
            onToggle: onToggle,
            items: [
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
    ),
  ),
);

/// A drawer whose section opens and closes on its own; returns the states it was toggled to.
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

Finder get _header => find.byKey(const ValueKey('drawer-section-toggle'));

void main() {
  testWidgets('open: the header shows the title in capitals and the items are there', (tester) async {
    await _pumpLive(tester);
    expect(find.text(_title.toUpperCase()), findsOneWidget);
    expect(find.text('Viaggi'), findsOneWidget);
    expect(tester.getSize(_header).height, greaterThanOrEqualTo(48));
  });

  testWidgets('tapping the header closes the section: its items leave the tree, then it opens again', (tester) async {
    final toggles = await _pumpLive(tester);
    await tester.tap(_header);
    await tester.pumpAndSettle();
    expect(toggles, [false]);
    expect(find.text('Viaggi'), findsNothing);
    await tester.tap(_header);
    await tester.pumpAndSettle();
    expect(find.text('Viaggi'), findsOneWidget);
  });

  testWidgets('the header is a button announced expanded or collapsed, named after the section', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpLive(tester);
    expect(
      tester.getSemantics(_header),
      matchesSemantics(label: _title, isButton: true, hasExpandedState: true, isExpanded: true, hasTapAction: true),
    );
    await tester.tap(_header);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(_header),
      matchesSemantics(label: _title, isButton: true, hasExpandedState: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('closing hides the items from the screen reader and from Tab while they leave', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpLive(tester);
    await tester.tap(_header);
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

  testWidgets('Enter and Space on the focused header toggle it', (tester) async {
    final toggles = await _pumpLive(tester);
    bool onHeader() {
      final focused = FocusManager.instance.primaryFocus?.context;
      return focused != null &&
          find.descendant(of: _header, matching: find.byElementPredicate((e) => e == focused)).evaluate().isNotEmpty;
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

  testWidgets('closed with an unread item: the dot shows and is read with the header; none when open', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpLive(tester, unread: true);
    expect(find.descendant(of: _header, matching: find.byKey(const ValueKey('unread-dot'))), findsNothing);
    await tester.tap(_header);
    await tester.pumpAndSettle();
    expect(find.descendant(of: _header, matching: find.byKey(const ValueKey('unread-dot'))), findsOneWidget);
    expect(tester.getSemantics(_header).label, '$_title, Non letto');
    semantics.dispose();
  });

  testWidgets('closed without unread: no dot', (tester) async {
    await _pumpLive(tester);
    await tester.tap(_header);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
  });

  testWidgets('closing the section of the active item moves the highlight to the header', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpLive(tester, active: true);
    final theme = PostinoTheme.light();
    final color = theme.extension<PostinoColors>()!.drawerItemBgActive;
    final box = find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == color,
    );
    expect(tester.getRect(box), tester.getRect(find.ancestor(of: find.text('Viaggi'), matching: find.byType(InkWell))));
    await tester.tap(_header);
    await tester.pumpAndSettle();
    expect(tester.getRect(box), tester.getRect(find.descendant(of: _header, matching: find.byType(InkWell))));
    expect(tester.getSemantics(_header).flagsCollection.isSelected, Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('rail: a 48×48 chevron with the title as tooltip, no text; the icons below when open', (tester) async {
    var expanded = true;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) =>
            _drawer(rail: true, unread: true, expanded: expanded, onToggle: () => setState(() => expanded = !expanded)),
      ),
    );
    await tester.pumpAndSettle();
    final inkwell = find.descendant(of: _header, matching: find.byType(InkWell));
    expect(tester.getSize(inkwell), const Size(48, 48));
    expect(find.text(_title.toUpperCase()), findsNothing);
    expect(find.byTooltip(_title), findsOneWidget);
    expect(find.byTooltip('Viaggi'), findsOneWidget);
    await tester.tap(_header);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Viaggi'), findsNothing);
    expect(find.descendant(of: _header, matching: find.byKey(const ValueKey('unread-dot'))), findsOneWidget);
  });
}
