// Swiping a row of the list (#147): left Archivia and right Segna come letto by default, the Azioni of the
// Impostazioni when changed (also after a restart), nothing below the threshold, «Applica Etichetta» opening the
// picker, and the same two Azioni as semantic actions of the row.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/model_download.dart';
import 'package:postino/core/domain/swipe_actions.dart';
import 'package:postino/core/domain/swipe_actions_repository.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/fake_model_download.dart';
import '../../support/harness.dart';

late Harness h;
late FakeMailProvider gmail;

DateTime _day(int d) => DateTime.utc(2026, 10, d, 9);

/// The list, newest first: x (x1, unread), o (o1, read), t (m1, m2, read).
Future<void> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(500, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  await getIt.unregister<ModelDownload>();
  getIt.registerSingleton<ModelDownload>(FakeModelDownload());
  gmail = await h.addAccount('a1');
  gmail.labels.add(const Label(id: 'Label_13', name: 'Fatture', kind: LabelKind.etichetta));
  gmail
    ..deliver(msg('m1', conversationId: 't', subject: 'Cena', date: _day(1), isRead: true))
    ..deliver(msg('m2', conversationId: 't', subject: 'Re: Cena', date: _day(2), isRead: true))
    ..deliver(msg('o1', conversationId: 'o', subject: 'Altro', date: _day(3), isRead: true))
    ..deliver(msg('x1', conversationId: 'x', subject: 'Ultimo', date: _day(4)));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await _run(tester);
}

Future<void> _run(WidgetTester tester) async {
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

/// Bounded pumps, never pumpAndSettle once a Snackbar shows: it ticks every second.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(pumpEventQueue);
  }
}

Future<void> _swipe(WidgetTester tester, String latest, double dx) async {
  await tester.drag(_row(latest), Offset(dx, 0));
  await _settle(tester);
}

/// The Annulla window ends: on the app's clock (the held voci) and on the test's (the snackbar).
Future<void> _expire(WidgetTester tester) async {
  h.clock.advance(PostinoMotion.undoWindow);
  await tester.pump(PostinoMotion.undoWindow + const Duration(seconds: 1));
  await _settle(tester);
}

Finder _row(String latest) => find.byKey(ValueKey('row-a1-$latest'));
PostinoMessageTile _tile(WidgetTester tester, String latest) => tester.widget<PostinoMessageTile>(_row(latest));
Finder get _snackbar => find.byType(PostinoSnackbar);

/// The Azioni that reached the Provider, comparable.
List<(String, MailAction)> get _sent => [for (final (id, action, _) in gmail.actionCalls) (id, action)];

Future<void> _choose(SwipeDirection direction, SwipeAction action) =>
    getIt<SwipeActionsRepository>().set(direction, action);

void main() {
  testWidgets('left Archivia by default: the row leaves at once behind Annulla, the Provider hears of it later', (
    tester,
  ) async {
    await _start(tester);
    await _swipe(tester, 'o1', -200);
    expect(_row('o1'), findsNothing);
    expect(find.text('Conversazione archiviata'), findsOneWidget);
    expect(_sent, isEmpty);

    await _expire(tester);
    expect(_sent, contains(('o1', const Archive())));
  });

  testWidgets('Annulla of a swipe is the one of the other ways: the row comes back', (tester) async {
    await _start(tester);
    await _swipe(tester, 'o1', -200);
    await tester.tap(find.widgetWithText(PostinoButton, 'Annulla'));
    await _settle(tester);
    expect(_row('o1'), findsOneWidget);
    await _expire(tester);
    expect(_sent, isEmpty);
  });

  testWidgets('right Segna come letto by default, and on a row already read it alternates to non letto', (
    tester,
  ) async {
    await _start(tester);
    expect(_tile(tester, 'x1').unread, isTrue);
    await _swipe(tester, 'x1', 200);
    expect(_tile(tester, 'x1').unread, isFalse);
    expect(_sent, contains(('x1', const MarkRead())));

    await _swipe(tester, 'x1', 200);
    expect(_tile(tester, 'x1').unread, isTrue);
    expect(_sent, contains(('x1', const MarkUnread())));
    expect(_snackbar, findsNothing);
  });

  testWidgets('below the threshold the gesture is cancelled with no effect', (tester) async {
    await _start(tester);
    await _swipe(tester, 'o1', -60);
    await _swipe(tester, 'x1', 60);
    expect(_row('o1'), findsOneWidget);
    expect(_tile(tester, 'x1').unread, isTrue);
    expect(_snackbar, findsNothing);
    expect(tester.getTopLeft(_row('o1')).dx, 0);
    await _expire(tester);
    expect(_sent, isEmpty);
  });

  testWidgets('while dragging the row shows the Azione behind it, and the row stays after the release', (tester) async {
    await _start(tester);
    expect(find.text('Archivia'), findsNothing);
    final drag = await tester.startGesture(tester.getCenter(_row('o1')));
    await drag.moveBy(const Offset(-40, 0));
    await drag.moveBy(const Offset(-40, 0));
    await tester.pump();
    expect(find.text('Archivia'), findsOneWidget);
    // Past the threshold the row resists: it moves less than the finger.
    await drag.moveBy(const Offset(-200, 0));
    await tester.pump();
    final shift = -tester.getTopLeft(_row('o1')).dx;
    expect(shift, greaterThan(PostinoSize.swipeThreshold));
    expect(shift, lessThan(280));

    await drag.up();
    await _settle(tester);
    expect(find.text('Archivia'), findsNothing);
  });

  testWidgets('the Azioni of the Impostazioni apply, also after the app restarts', (tester) async {
    await _start(tester);
    await _choose(SwipeDirection.left, SwipeAction.delete);
    await _choose(SwipeDirection.right, SwipeAction.star);
    await _settle(tester);

    await tester.pumpWidget(const SizedBox());
    await _run(tester);
    await _swipe(tester, 'o1', -200);
    expect(find.text('Conversazione spostata nel Cestino'), findsOneWidget);
    expect(_row('o1'), findsNothing);

    await _swipe(tester, 'x1', 200);
    expect(_tile(tester, 'x1').starred, isTrue);
    expect(_sent, contains(('x1', const Star())));
    await _swipe(tester, 'x1', 200);
    expect(_tile(tester, 'x1').starred, isFalse);
    expect(_sent, contains(('x1', const Unstar())));
  });

  testWidgets('Applica Etichetta opens the picker; closing it without a choice leaves the row as it was', (
    tester,
  ) async {
    await _start(tester);
    await _choose(SwipeDirection.left, SwipeAction.applyLabel);
    await _settle(tester);
    await _swipe(tester, 'o1', -200);
    expect(find.byKey(const ValueKey('label-search')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byKey(const ValueKey('label-search')), findsNothing);
    expect(_row('o1'), findsOneWidget);
    expect(_tile(tester, 'o1').labels, isEmpty);
    expect(_snackbar, findsNothing);
    await _expire(tester);
    expect(_sent, isEmpty);
    expect(gmail.labelCalls, isEmpty);
  });

  testWidgets('screen reader: the row exposes the two Azioni of the swipes as custom actions, and they act', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final semantics = tester.ensureSemantics();
    try {
      await _start(tester);
      await _choose(SwipeDirection.right, SwipeAction.applyLabel);
      await _settle(tester);

      SemanticsNode rowNode() => tester.getSemantics(_row('o1'));
      int id(String label) => CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label));
      final ids = rowNode().getSemanticsData().customSemanticsActionIds ?? const [];
      expect(ids, containsAll([id('Archivia'), id('Applica Etichetta')]));

      final node = rowNode();
      node.owner!.performAction(node.id, SemanticsAction.customAction, id('Archivia'));
      await _settle(tester);
      expect(_row('o1'), findsNothing);
      expect(find.text('Conversazione archiviata'), findsOneWidget);

      final other = tester.getSemantics(_row('x1'));
      other.owner!.performAction(other.id, SemanticsAction.customAction, id('Applica Etichetta'));
      await _settle(tester);
      expect(find.byKey(const ValueKey('label-search')), findsOneWidget);
    } finally {
      semantics.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
