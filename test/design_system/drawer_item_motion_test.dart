// PostinoDrawerItemTile (#283): the unread dot and the Da ricollegare badge fade in and out (duration-toggle), in the
// extended drawer and in the icon rail; at the first build they are just there; reduced motion is instant. A dot on
// its way out is not read; an absent one takes no room.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

import '../support/ui.dart';

Widget _drawer({bool unread = false, bool reconnect = false, bool collapsed = false, bool reduced = false}) =>
    MaterialApp(
      theme: PostinoTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: PostinoSidebarScope(
            collapsed: collapsed,
            toggleLabel: 'Barra',
            toggle: () {},
            child: PostinoNavigationDrawer(
              sections: [
                PostinoDrawerSection(
                  items: [
                    PostinoDrawerItem(
                      label: 'Lavoro',
                      account: (color: PostinoAccountColor.values.first, initial: 'L'),
                      unreadLabel: unread ? 'Non letti' : null,
                      reconnectLabel: reconnect ? 'Da ricollegare' : null,
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

const _dot = ValueKey('unread-dot');

void main() {
  final half = PostinoMotion.toggle ~/ 2;

  for (final collapsed in [false, true]) {
    final where = collapsed ? 'rail' : 'drawer';

    testWidgets('$where: the unread dot fades in, then out unread no more', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_drawer(collapsed: collapsed));
      await tester.pumpWidget(_drawer(unread: true, collapsed: collapsed));
      await tester.pump(half);
      expect(shownOpacity(tester, find.byKey(_dot)), inExclusiveRange(0, 1));
      await tester.pump(half);
      expect(shownOpacity(tester, find.byKey(_dot)), 1);

      await tester.pumpWidget(_drawer(collapsed: collapsed));
      await tester.pump(half);
      expect(find.byKey(_dot), findsOneWidget, reason: 'still drawn while it fades');
      expect(shownOpacity(tester, find.byKey(_dot)), inExclusiveRange(0, 1));
      if (!collapsed) expect(find.semantics.byLabel('Non letti'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byKey(_dot), findsNothing);
      handle.dispose();
    });

    testWidgets('$where: the Da ricollegare badge fades in; at the first build it is just there', (tester) async {
      await tester.pumpWidget(_drawer(reconnect: true, collapsed: collapsed));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(_drawer(collapsed: collapsed));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_drawer(reconnect: true, collapsed: collapsed));
      await tester.pump(half);
      final badge = collapsed
          ? find.byKey(const ValueKey('reconnect-badge'))
          : find.byWidgetPredicate((w) => w is PostinoSyncStatus && w.state == PostinoSyncState.reconnect);
      expect(shownOpacity(tester, badge), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(shownOpacity(tester, badge), 1);
    });
  }

  testWidgets('an absent dot takes no room: the name reaches where the dot ends', (tester) async {
    await tester.pumpWidget(_drawer(unread: true));
    final dot = tester.getTopRight(find.byKey(_dot)).dx;
    final name = tester.getTopRight(find.text('Lavoro')).dx;
    expect(tester.getTopLeft(find.byKey(_dot)).dx - name, PostinoSpacing.s3);
    await tester.pumpWidget(_drawer());
    await tester.pumpAndSettle();
    expect(tester.getTopRight(find.text('Lavoro')).dx, dot);
  });

  testWidgets('with reduced motion the dot comes and goes at once', (tester) async {
    await tester.pumpWidget(_drawer(reduced: true));
    await tester.pumpWidget(_drawer(unread: true, reduced: true));
    await tester.pump();
    expect(shownOpacity(tester, find.byKey(_dot)), 1);
    await tester.pumpWidget(_drawer(reduced: true));
    await tester.pump();
    expect(find.byKey(_dot), findsNothing);
  });
}
