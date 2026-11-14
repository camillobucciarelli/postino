// PostinoSidebarShell (#283): opening and closing the docked sidebar slides its width; the drawer turns to icons only
// once the edge is back, the focus stays on the button, and reduced motion makes it instant.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

const _drawer = ValueKey('drawer');

Widget _shell({bool reduced = false}) => MaterialApp(
  theme: PostinoTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(size: const Size(1600, 900), disableAnimations: reduced),
      child: Scaffold(
        body: PostinoSidebarShell(
          closeLabel: 'Chiudi la barra',
          openLabel: 'Apri la barra',
          drawer: PostinoNavigationDrawer(
            key: _drawer,
            sections: [
              PostinoDrawerSection(
                title: 'Caselle',
                items: [
                  PostinoDrawerItem(label: 'Posta in arrivo', icon: PostinoIcons.inbox, active: true, onTap: () {}),
                ],
              ),
            ],
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  ),
);

double _width(WidgetTester tester) =>
    tester.getSize(find.ancestor(of: find.byKey(_drawer), matching: find.byType(ClipRect)).first).width;

Future<void> _toggle(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip(label));
  await tester.pump();
}

void main() {
  final half = PostinoMotion.menuIndicator ~/ 2;
  final k = PostinoMotion.emphasized.transform(0.5);
  const wide = PostinoSize.sidebarWidth;
  const narrow = PostinoSize.sidebarCollapsedWidth;

  testWidgets('closing: half way the width is between, the names still there and cut; then icons', (tester) async {
    await tester.pumpWidget(_shell());
    expect(_width(tester), wide);
    expect(tester.hasRunningAnimations, isFalse, reason: 'nothing moves at the start');
    await _toggle(tester, 'Chiudi la barra');
    await tester.pump(half);
    expect(_width(tester), closeTo(wide + (narrow - wide) * k, 0.5));
    expect(find.text('Posta in arrivo'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'nothing squeezed');
    await tester.pump(half);
    await tester.pump();
    expect(_width(tester), narrow);
    expect(find.text('Posta in arrivo'), findsNothing, reason: 'icons only');
  });

  testWidgets('opening: the names are laid out at once and uncovered by the edge; the focus stays', (tester) async {
    await tester.pumpWidget(_shell());
    await _toggle(tester, 'Chiudi la barra');
    await tester.pumpAndSettle();
    final button = Focus.of(
      tester.element(find.descendant(of: find.byTooltip('Apri la barra'), matching: find.byType(PostinoIcon)).first),
    )..requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(half);
    expect(_width(tester), closeTo(narrow + (wide - narrow) * k, 0.5));
    expect(find.text('Posta in arrivo'), findsOneWidget);
    expect(button.hasFocus, isTrue);
    await tester.pumpAndSettle();
    expect(_width(tester), wide);
    expect(button.hasFocus, isTrue);
    expect(find.byTooltip('Chiudi la barra'), findsOneWidget);
  });

  testWidgets('with reduced motion the width changes at once', (tester) async {
    await tester.pumpWidget(_shell(reduced: true));
    await _toggle(tester, 'Chiudi la barra');
    await tester.pump();
    expect(_width(tester), narrow);
    expect(find.text('Posta in arrivo'), findsNothing);
  });
}
