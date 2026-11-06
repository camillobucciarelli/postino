// Impostazioni › Azioni per scorrimento (#147): the Azione of each direction, chosen with the pointer or the keyboard,
// kept for the next run, and used by the list.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/swipe_actions.dart';
import 'package:postino/core/domain/swipe_actions_repository.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

Future<void> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1200, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  final provider = await h.addAccount('a1');
  provider.deliver(msg('x', subject: 'Una email', isRead: true));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await _run(tester);
}

Future<void> _run(WidgetTester tester) async {
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

Future<void> _openPage(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('drawer-impostazioni')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('settings-swipe')));
  await tester.pumpAndSettle();
}

Finder _choice(SwipeDirection d, SwipeAction a) => find.byKey(ValueKey('swipe-${d.name}-${a.name}'));

Future<SwipeActions> _saved() => getIt<SwipeActionsRepository>().watch().first;

void main() {
  testWidgets('the page offers the five Azioni for each direction, with the defaults chosen', (tester) async {
    await _start(tester);
    await _openPage(tester);
    expect(find.text('Azioni per scorrimento'), findsWidgets);
    expect(find.text('SCORRIMENTO A SINISTRA'), findsOneWidget);
    expect(find.text('SCORRIMENTO A DESTRA'), findsOneWidget);
    for (final label in ['Archivia', 'Segna come letto/non letto', 'Stella', 'Elimina', 'Applica Etichetta']) {
      expect(find.text(label), findsNWidgets(2), reason: label);
    }
    expect(
      tester.getSemantics(_choice(SwipeDirection.left, SwipeAction.archive)),
      isSemantics(
        label: 'Archivia',
        isButton: true,
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    expect(
      tester.getSemantics(_choice(SwipeDirection.left, SwipeAction.delete)),
      isSemantics(
        label: 'Elimina',
        isButton: true,
        hasCheckedState: true,
        isChecked: false,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    expect((await tester.runAsync(_saved))!, swipeActionsDefault);
  });

  testWidgets('a tap chooses the Azione of that direction only, and it is kept after a restart', (tester) async {
    await _start(tester);
    await _openPage(tester);
    await tester.tap(_choice(SwipeDirection.left, SwipeAction.delete));
    await tester.pumpAndSettle();
    await tester.tap(_choice(SwipeDirection.right, SwipeAction.applyLabel));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(_saved))!, (left: SwipeAction.delete, right: SwipeAction.applyLabel));

    await tester.pumpWidget(const SizedBox());
    await _run(tester);
    await _openPage(tester);
    expect((await tester.runAsync(_saved))!, (left: SwipeAction.delete, right: SwipeAction.applyLabel));
    expect(
      tester.getSemantics(_choice(SwipeDirection.left, SwipeAction.delete)),
      isSemantics(
        label: 'Elimina',
        isButton: true,
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
  });

  testWidgets('keyboard: Tab reaches a choice, Enter chooses it, Esc goes back', (tester) async {
    await _start(tester);
    await _openPage(tester);
    final target = _choice(SwipeDirection.right, SwipeAction.star);
    var tabs = 0;
    bool onTarget() {
      final focused = FocusManager.instance.primaryFocus?.context;
      return focused != null &&
          find
              .ancestor(of: find.byElementPredicate((e) => identical(e, focused)), matching: target)
              .evaluate()
              .isNotEmpty;
    }

    while (!onTarget() && tabs++ < 40) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(onTarget(), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect((await tester.runAsync(_saved))!, (left: SwipeAction.archive, right: SwipeAction.star));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('SCORRIMENTO A SINISTRA'), findsNothing);
  });
}
