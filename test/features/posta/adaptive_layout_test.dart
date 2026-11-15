import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/posta_drawer.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import '../../support/ui.dart';

Future<void> _start(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  (await h.addAccount('a1'))
    ..deliver(msg('x', subject: 'Da uno'))
    ..deliver(msg('l', subject: 'In viaggio', labelIds: const ['Label_12']));
  (await h.addAccount('a2')).deliver(msg('y', subject: 'Da due'));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  // Routefly keeps the last navigation in statics.
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on a phone the drawer is modal, behind the menu', (tester) async {
    await _start(tester, const Size(390, 844));
    expect(find.byKey(const ValueKey('account-a1')), findsNothing);
    expect(icon(PostinoIcons.menu), findsOneWidget);

    await openDrawer(tester);
    expect(find.byKey(const ValueKey('account-a1')), findsOneWidget);
    expect(tester.getSize(find.byType(PostinoNavigationDrawer)).width, PostinoSize.drawerWidth);
  });

  testWidgets('from 840 the drawer is docked beside the list, with no menu, and still navigates', (tester) async {
    await _start(tester, const Size(1600, 900));
    final sidebar = find.byType(PostinoNavigationDrawer);
    expect(sidebar, findsOneWidget);
    expect(tester.getSize(sidebar).width, PostinoSize.sidebarWidth);
    expect(tester.getTopLeft(sidebar).dx, 0);
    expect(icon(PostinoIcons.menu), findsNothing);
    // The list sits right of the sidebar at list-width, the detail pane after it.
    final row = find.byKey(const ValueKey('row-a1-x'));
    expect(tester.getTopLeft(row).dx, PostinoSize.sidebarWidth);
    expect(tester.getTopRight(row).dx, PostinoSize.sidebarWidth + PostinoSize.listWidth);
    expect(find.text('Seleziona una Conversazione'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('inbox-a1')));
    await tester.pumpAndSettle();
    expect(find.text('Da uno'), findsOneWidget);
    expect(find.text('Da due'), findsNothing);
    expect(find.byType(PostinoNavigationDrawer), findsOneWidget);
  });

  testWidgets('docked, navigating replaces only the content: the drawer State survives', (tester) async {
    await _start(tester, const Size(1600, 900));
    State drawer() => tester.state(find.byType(PostaDrawer));
    final first = drawer();
    Future<void> go(String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(drawer(), same(first), reason: 'after $key');
    }

    await go('inbox-a1');
    await go('label-a1-Label_12');
    await go('inbox-a2');
    await go('drawer-posta-unificata');
  });
}
