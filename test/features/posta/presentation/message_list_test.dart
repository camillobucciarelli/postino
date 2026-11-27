// The list of Conversazioni (the twin of message_list.dart for the mutation test): the cursor follows a focus that
// came some other way, the number of rows is reported when it changes, and rows leave and arrive animated (#282).
// Most rows are read: the list has no sections; the sections of the posta in arrivo (#366) have their own group.
import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/app/posta/posta_routes.dart' show labelPath;
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/mail_action.dart' show readAttribute, starredAttribute;
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/inbox_section_screen.dart';
import 'package:postino/features/posta/presentation/message_list.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/harness.dart';

/// Rows `m1` to `m[count]`, newest first: the last is the first row. [frame] runs after each frame of the first load
/// instead of settling it.
Future<FakeMailProvider> _start(WidgetTester tester, {int count = 5, void Function()? frame}) async {
  tester.view
    ..physicalSize = const Size(1600, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  final p = await h.addAccount('a1');
  for (var i = 1; i <= count; i++) {
    p.deliver(
      msg('m$i', subject: 'Fattura $i', date: DateTime.utc(2026, 10, 1, 9, i), conversationId: 't$i', isRead: true),
    );
  }
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  // Routefly keeps the last navigation in statics.
  unawaited(Routefly.navigate(routePaths.posta.path));
  if (frame == null) {
    await tester.pumpAndSettle();
    return p;
  }
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    frame();
  }
  return p;
}

/// The number of the row that has the focus, null when focus is elsewhere.
int? _focusedRow() {
  final key = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<PostinoMessageTile>()?.key;
  return key is ValueKey<String> ? int.parse(key.value.split('-m').last) : null;
}

Finder _fadeOf(int i) => find.ancestor(of: find.byKey(ValueKey('row-a1-m$i')), matching: find.byType(PostinoSizeFade));

/// How visible row `m$i` is: its fade, and its height against the row's own (both 1 at rest).
({double opacity, double height}) _visible(WidgetTester tester, int i) {
  final fade = _fadeOf(i);
  final opacity = tester
      .widget<FadeTransition>(find.descendant(of: fade, matching: find.byType(FadeTransition)).first)
      .opacity
      .value;
  final full = tester.getSize(find.byKey(ValueKey('row-a1-m$i'))).height;
  final height = tester.getSize(find.descendant(of: fade, matching: find.byType(SizeTransition)).first).height;
  return (opacity: opacity, height: height / full);
}

/// The sync writes the database; one frame lets the list take the new rows, before any time passes.
Future<void> _syncNoSettle(WidgetTester tester) async {
  await getIt<SyncEngine>().syncAll();
  await tester.pump();
}

Future<void> _focus(WidgetTester tester, int i) async {
  final row = find.descendant(of: find.byKey(ValueKey('row-a1-m$i')), matching: find.byType(PostinoFocusRing));
  Focus.of(tester.element(row)).requestFocus();
  await tester.pumpAndSettle();
  expect(_focusedRow(), i);
}

/// Swipes row `m$i` by [dx] (left Archivia, right Segna come letto by default) and lets the database act, with no
/// time passing on the test's clock.
Future<void> _swipe(WidgetTester tester, int i, {double dx = -300}) async {
  final g = await tester.startGesture(tester.getCenter(find.byKey(ValueKey('row-a1-m$i'))));
  await g.moveBy(Offset(dx.sign * 20, 0));
  await g.moveBy(Offset(dx - dx.sign * 20, 0));
  // A frame under the finger, as on a device: the release starts from where the row is drawn.
  await tester.pump();
  await g.up();
  await tester.pump();
  for (var n = 0; n < 8; n++) {
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
  }
}

/// Where row `m$i` is sideways, in its own widths: 0 in place, -1 off the screen to the left.
double _shift(WidgetTester tester, int i) {
  final fade = _fadeOf(i);
  return (tester.getTopLeft(find.byKey(ValueKey('row-a1-m$i'))).dx - tester.getTopLeft(fade).dx) /
      tester.getSize(fade).width;
}

bool _leaving(WidgetTester tester, int i) => tester.widget<PostinoSizeFade>(_fadeOf(i)).leaving;

Future<void> _removeRemotely(WidgetTester tester, FakeMailProvider p, Iterable<int> ids) async {
  for (final i in ids) {
    p.removeRemotely('m$i');
  }
  await getIt<SyncEngine>().syncAll();
  await tester.pumpAndSettle();
}

/// `s1..s[starred]` with a Stella, `u1..u[unread]` unread, `r1..r[read]` read; in each group the first is the newest,
/// and the groups come newest first in that order, as the sections do.
Future<FakeMailProvider> _startSections(
  WidgetTester tester, {
  int starred = 0,
  int unread = 0,
  int read = 0,
  double width = 1600,
}) async {
  tester.view
    ..physicalSize = Size(width, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  final p = await h.addAccount('a1');
  var minute = 59;
  void add(String prefix, int n, {bool isRead = true, bool star = false}) {
    for (var i = 1; i <= n; i++) {
      p.deliver(
        msg(
          '$prefix$i',
          subject: 'Oggetto $prefix$i',
          date: DateTime.utc(2026, 10, 1, 9, minute--),
          conversationId: 't-$prefix$i',
          isRead: isRead,
          isStarred: star,
          labelIds: [inboxLabelId, if (star) starredLabelId],
        ),
      );
    }
  }

  add('s', starred, star: true);
  add('u', unread, isRead: false);
  add('r', read);
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  // Routefly keeps the last navigation in statics.
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  return p;
}

Finder _rowOf(String id) => find.byKey(ValueKey('row-a1-$id'));

/// The headings, top to bottom, as drawn.
List<String> _headings(WidgetTester tester) => [
  for (final h in tester.widgetList<PostinoSectionHeader>(find.byType(PostinoSectionHeader))) '${h.title} ${h.count}',
];

/// The id of the row that has the focus, null when focus is elsewhere.
String? _focusedId() {
  final key = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<PostinoMessageTile>()?.key;
  return key is ValueKey<String> ? key.value.split('-').last : null;
}

double _topOf(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

void main() {
  testWidgets('the focused row leaves the list: the focus goes to the row now in its place, and j / k go on', (
    tester,
  ) async {
    final p = await _start(tester);
    await _focus(tester, 3);
    await _removeRemotely(tester, p, [3]);
    expect(_focusedRow(), 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(_focusedRow(), 1, reason: 'from the row that took the place, not from the first');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(_focusedRow(), 2);
  });

  testWidgets('the last row leaves the list: the focus goes to the one before', (tester) async {
    final p = await _start(tester);
    await _focus(tester, 1);
    await _removeRemotely(tester, p, [1]);
    expect(_focusedRow(), 2);
  });

  testWidgets('a focus that is not on the list is not taken when the cursor row leaves', (tester) async {
    final p = await _start(tester);
    await _focus(tester, 3);
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(_focusedRow(), isNull);
    await _removeRemotely(tester, p, [3]);
    expect(_focusedRow(), isNull);
  });

  testWidgets('the list empties: nothing breaks, and a row coming back shows', (tester) async {
    final p = await _start(tester);
    await _focus(tester, 3);
    await _removeRemotely(tester, p, [1, 2, 3, 4, 5]);
    expect(find.byType(PostinoMessageTile), findsNothing);
    p.deliver(msg('m9', subject: 'Nuova', date: DateTime.utc(2026, 10, 2), conversationId: 't9', isRead: true));
    await getIt<SyncEngine>().syncAll();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('row-a1-m9')), findsOneWidget);
  });

  testWidgets('a row focused some other way becomes the cursor: the next move starts from it', (tester) async {
    await _start(tester);
    expect(find.byType(MessageList), findsOneWidget);
    Future<void> focus(int i) async {
      final row = find.descendant(of: find.byKey(ValueKey('row-a1-m$i')), matching: find.byType(PostinoFocusRing));
      Focus.of(tester.element(row)).requestFocus();
      await tester.pumpAndSettle();
      expect(_focusedRow(), i);
    }

    await focus(4);
    await focus(3);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(_focusedRow(), 2, reason: 'one row on from the one focused, not from the first');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(_focusedRow(), 1, reason: 'and on again: a row that lost the focus is not the cursor');
  });

  testWidgets('the number of results of the search is announced, and again when it changes', (tester) async {
    final handle = tester.ensureSemantics();
    await _start(tester);
    await tester.tap(find.byTooltip('Cerca'));
    await tester.pumpAndSettle();
    final live = find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true);

    await tester.enterText(find.byType(TextField), 'fattura');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(live).label, '5 risultati');

    await tester.enterText(find.byType(TextField), 'fattura 3');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(live).label, '1 risultato');
    handle.dispose();
  });

  group('motion (#282)', () {
    testWidgets('a row that leaves fades while its height closes, then is gone; the rows under it move up', (
      tester,
    ) async {
      final p = await _start(tester);
      final below = tester.getTopLeft(find.byKey(const ValueKey('row-a1-m2'))).dy;
      final rowHeight = tester.getSize(find.byKey(const ValueKey('row-a1-m3'))).height;
      p.removeRemotely('m3');
      await _syncNoSettle(tester);
      await tester.pump(PostinoMotion.swipeDismiss ~/ 2);
      final mid = _visible(tester, 3);
      expect(mid.opacity, inExclusiveRange(0, 1));
      expect(mid.height, inExclusiveRange(0, 1));
      expect(tester.getTopLeft(find.byKey(const ValueKey('row-a1-m2'))).dy, inExclusiveRange(below - rowHeight, below));
      await tester.pump(PostinoMotion.swipeDismiss);
      await tester.pump();
      expect(find.byKey(const ValueKey('row-a1-m3')), findsNothing);
      expect(tester.getTopLeft(find.byKey(const ValueKey('row-a1-m2'))).dy, below - rowHeight);
    });

    testWidgets('a row on its way out takes no taps and is not read', (tester) async {
      final handle = tester.ensureSemantics();
      final p = await _start(tester);
      p.removeRemotely('m3');
      await _syncNoSettle(tester);
      await tester.pump(PostinoMotion.swipeDismiss ~/ 2);
      expect(find.semantics.byLabel(RegExp('Fattura 3')), findsNothing);
      expect(find.semantics.byLabel(RegExp('Fattura 2')), findsOne);
      await tester.tap(find.byKey(const ValueKey('row-a1-m3')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(PostinoThreadView), findsNothing, reason: 'nothing opened');
      handle.dispose();
    });

    testWidgets('a row that arrives opens its height and fades in', (tester) async {
      final p = await _start(tester);
      p.deliver(msg('m9', subject: 'Nuova', date: DateTime.utc(2026, 10, 2), conversationId: 't9', isRead: true));
      await _syncNoSettle(tester);
      await tester.pump(PostinoMotion.rowEnter ~/ 2);
      final mid = _visible(tester, 9);
      expect(mid.opacity, inExclusiveRange(0, 1));
      expect(mid.height, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_visible(tester, 9), (opacity: 1.0, height: 1.0));
    });

    testWidgets('a row archived and brought back with Annulla comes back animated', (tester) async {
      await _start(tester);
      await _focus(tester, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(pumpEventQueue);
      }
      expect(find.byKey(const ValueKey('row-a1-m3')), findsNothing);
      await tester.tap(find.widgetWithText(PostinoButton, 'Annulla'));
      // The database writes are real I/O: no time passes on the test's clock until the row is back.
      for (var i = 0; i < 8 && find.byKey(const ValueKey('row-a1-m3')).evaluate().isEmpty; i++) {
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
      }
      await tester.pump(PostinoMotion.rowEnter ~/ 2);
      expect(_visible(tester, 3).opacity, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_visible(tester, 3), (opacity: 1.0, height: 1.0));
    });

    testWidgets('the first load does not animate, frame by frame', (tester) async {
      var seen = 0;
      await _start(
        tester,
        frame: () {
          // The rows only: the banners above the list fade in their own way (PostinoReveal, #283).
          final rows = find.descendant(of: find.byType(MessageList), matching: find.byType(PostinoSizeFade));
          for (final f in tester.widgetList<PostinoSizeFade>(rows)) {
            seen++;
            expect(f.visibility, kAlwaysCompleteAnimation);
          }
        },
      );
      expect(seen, greaterThan(0), reason: 'the rows came during the frames watched');
      expect(find.byKey(const ValueKey('row-a1-m5')), findsOneWidget);
    });

    testWidgets('the last row archived and brought back with Annulla comes back animated', (tester) async {
      await _start(tester, count: 1);
      await _focus(tester, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(pumpEventQueue);
      }
      expect(find.byKey(const ValueKey('row-a1-m1')), findsNothing);
      await tester.tap(find.widgetWithText(PostinoButton, 'Annulla'));
      for (var i = 0; i < 8 && find.byKey(const ValueKey('row-a1-m1')).evaluate().isEmpty; i++) {
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
      }
      await tester.pump(PostinoMotion.rowEnter ~/ 2);
      expect(_visible(tester, 1).opacity, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_visible(tester, 1), (opacity: 1.0, height: 1.0));
    });

    testWidgets('a row that arrives and leaves on the next frame just goes', (tester) async {
      final p = await _start(tester);
      p.deliver(msg('m9', subject: 'Nuova', date: DateTime.utc(2026, 10, 2), conversationId: 't9', isRead: true));
      await _syncNoSettle(tester);
      p.removeRemotely('m9');
      await _syncNoSettle(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('row-a1-m9')), findsNothing);
      expect(find.byKey(const ValueKey('row-a1-m5')), findsOneWidget);
    });

    testWidgets('many rows leave at once above the focused one: the focus stays in the list', (tester) async {
      final p = await _start(tester, count: 100);
      await _focus(tester, 100);
      for (var i = 2; i <= 100; i++) {
        p.removeRemotely('m$i', signal: false);
      }
      await _syncNoSettle(tester);
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      expect(_focusedRow(), 1);
    });

    testWidgets('with reduced motion rows leave and arrive at once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final p = await _start(tester);
      p
        ..removeRemotely('m3')
        ..deliver(msg('m9', subject: 'Nuova', date: DateTime.utc(2026, 10, 2), conversationId: 't9', isRead: true));
      await _syncNoSettle(tester);
      expect(find.byKey(const ValueKey('row-a1-m3')), findsNothing);
      expect(tester.widget<PostinoSizeFade>(_fadeOf(9)).visibility, kAlwaysCompleteAnimation);
    });

    testWidgets('while the focused row leaves the focus is already on the row taking its place', (tester) async {
      final p = await _start(tester);
      await _focus(tester, 3);
      p.removeRemotely('m3');
      await _syncNoSettle(tester);
      await tester.pump(PostinoMotion.swipeDismiss ~/ 2);
      expect(find.byKey(const ValueKey('row-a1-m3')), findsOneWidget);
      expect(_focusedRow(), 2);
      await tester.pumpAndSettle();
      expect(_focusedRow(), 2);
    });

    testWidgets('swiped to Archivia: the row goes off the screen, then the height closes without fading (#376)', (
      tester,
    ) async {
      await _start(tester);
      final below = tester.getTopLeft(find.byKey(const ValueKey('row-a1-m2'))).dy;
      final rowHeight = tester.getSize(find.byKey(const ValueKey('row-a1-m3'))).height;
      await _swipe(tester, 3);
      final released = _shift(tester, 3);
      expect(released, lessThan(0));
      await tester.pump(PostinoMotion.swipeDismiss ~/ 2);
      expect(_shift(tester, 3), inExclusiveRange(-1, released), reason: 'on its way out');
      expect(_visible(tester, 3), (opacity: 1.0, height: 1.0), reason: 'the list waits for the slide');
      await tester.pump(PostinoMotion.swipeDismiss ~/ 2);
      expect(_shift(tester, 3), -1, reason: 'off the screen');
      await tester.pump(PostinoMotion.swipeDismiss ~/ 2);
      final closing = _visible(tester, 3);
      expect(closing.height, inExclusiveRange(0, 1));
      expect(closing.opacity, 1, reason: 'no fade: the row is out already');
      expect(_shift(tester, 3), -1);
      expect(tester.getTopLeft(find.byKey(const ValueKey('row-a1-m2'))).dy, inExclusiveRange(below - rowHeight, below));
      await tester.pump(PostinoMotion.swipeDismiss);
      await tester.pump();
      expect(find.byKey(const ValueKey('row-a1-m3')), findsNothing);
      expect(tester.getTopLeft(find.byKey(const ValueKey('row-a1-m2'))).dy, below - rowHeight);
    });

    testWidgets('two quick swipes: the second row stays off the screen when the first one is gone above it (#376)', (
      tester,
    ) async {
      await _start(tester);
      await _swipe(tester, 4);
      await tester.pump(PostinoMotion.swipeDismiss);
      await _swipe(tester, 3);
      await tester.pump(PostinoMotion.swipeDismiss * 3 ~/ 2);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('row-a1-m4')),
        findsNothing,
        reason: 'the first one is gone: the second moved up',
      );
      expect(_shift(tester, 3), -1, reason: 'still off the screen, not back in place');
      final closing = _visible(tester, 3);
      expect(closing.height, inExclusiveRange(0, 1));
      expect(closing.opacity, 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('row-a1-m3')), findsNothing);
    });

    testWidgets('swiped to Segna come letto: the row goes back in place and stays (#376)', (tester) async {
      await _start(tester);
      await _swipe(tester, 3, dx: 300);
      await tester.pumpAndSettle();
      expect(_shift(tester, 3), 0);
      expect(_visible(tester, 3), (opacity: 1.0, height: 1.0));
    });

    testWidgets('swiped to Archivia and Annulla half way: the row turns round in place (#376)', (tester) async {
      await _start(tester);
      await _swipe(tester, 3);
      await tester.pump(PostinoMotion.swipeDismiss * 3 ~/ 2);
      final closing = _visible(tester, 3).height;
      expect(closing, inExclusiveRange(0, 1));
      await tester.tap(find.widgetWithText(PostinoButton, 'Annulla'));
      for (var i = 0; i < 8 && _leaving(tester, 3); i++) {
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
      }
      final back = _visible(tester, 3);
      expect(_shift(tester, 3), 0, reason: 'in place at once, not sliding back from the side');
      expect(back.height, closeTo(closing, 0.01), reason: 'the height turns round from where it was');
      expect(back.opacity, closeTo(back.height, 0.01), reason: 'and fades in with it, as any row coming back');
      await tester.pump(PostinoMotion.rowEnter ~/ 4);
      expect(_visible(tester, 3).opacity, inExclusiveRange(back.opacity, 1));
      await tester.pump(PostinoMotion.rowEnter);
      expect(_visible(tester, 3), (opacity: 1.0, height: 1.0));
      expect(_shift(tester, 3), 0);
    });

    testWidgets('swiped to Archivia with reduced motion: gone at once (#376)', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _start(tester);
      await _swipe(tester, 3);
      expect(find.byKey(const ValueKey('row-a1-m3')), findsNothing);
    });

    testWidgets('a row that comes back while leaving turns round', (tester) async {
      final p = await _start(tester);
      p.removeRemotely('m3');
      await _syncNoSettle(tester);
      await tester.pump(PostinoMotion.swipeDismiss ~/ 2);
      final out = _visible(tester, 3).opacity;
      p.deliver(
        msg('m3', subject: 'Fattura 3', date: DateTime.utc(2026, 10, 1, 9, 3), conversationId: 't3', isRead: true),
      );
      await _syncNoSettle(tester);
      await tester.pump(PostinoMotion.rowEnter ~/ 4);
      expect(_visible(tester, 3).opacity, greaterThan(out));
      await tester.pumpAndSettle();
      expect(_visible(tester, 3), (opacity: 1.0, height: 1.0));
    });
  });

  group('sections of the posta in arrivo (#366)', () {
    testWidgets('Da leggere, Contrassegnate, Letti in order, each heading with its count; 3 rows and «Mostra tutti»', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _startSections(tester, starred: 2, unread: 4, read: 2);
      expect(_headings(tester), ['Da leggere 4', 'Contrassegnate 2', 'Letti 2']);
      expect(_topOf(tester, _rowOf('u3')), lessThan(_topOf(tester, _rowOf('s1'))));
      expect(_topOf(tester, _rowOf('s2')), lessThan(_topOf(tester, _rowOf('r1'))));
      expect(_rowOf('u3'), findsOneWidget);
      expect(_rowOf('u4'), findsNothing, reason: 'only the 3 newest');
      expect(_rowOf('r2'), findsOneWidget, reason: 'Letti shows all');
      expect(
        find.widgetWithText(PostinoButton, 'Mostra tutti'),
        findsOneWidget,
        reason: 'only Da leggere has more than 3',
      );
      expect(
        find.semantics.byPredicate((n) => n.label == 'Da leggere, 4 conversazioni' && n.flagsCollection.isHeader),
        findsOne,
      );
      expect(find.semantics.byLabel('Mostra tutte le 4 Da leggere'), findsOne);
      handle.dispose();
    });

    testWidgets('without Contrassegnate nor Da leggere there is no heading: the list as before', (tester) async {
      await _startSections(tester, read: 3);
      expect(find.byType(PostinoSectionHeader), findsNothing);
      expect(_rowOf('r3'), findsOneWidget);
    });

    testWidgets('an empty section has no heading', (tester) async {
      await _startSections(tester, unread: 1, read: 1);
      expect(_headings(tester), ['Da leggere 1', 'Letti 1']);
      expect(find.widgetWithText(PostinoButton, 'Mostra tutti'), findsNothing);
    });

    testWidgets('a Conversazione with a Stella on an older message is Contrassegnata, and its row shows the Stella', (
      tester,
    ) async {
      final h = await Harness.create();
      final p = await h.addAccount('a1');
      p
        ..deliver(
          msg(
            'm1',
            date: DateTime.utc(2026, 10, 1, 9),
            conversationId: 't1',
            isRead: true,
            isStarred: true,
            labelIds: const [inboxLabelId, starredLabelId],
          ),
        )
        ..deliver(msg('m2', date: DateTime.utc(2026, 10, 1, 10), conversationId: 't1', isRead: true))
        ..deliver(msg('m3', date: DateTime.utc(2026, 10, 1, 8), conversationId: 't3', isRead: true));
      LocaleSettings.setLocaleSync(AppLocale.it);
      await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
      unawaited(Routefly.navigate(routePaths.posta.path));
      await tester.pumpAndSettle();
      expect(_headings(tester), ['Contrassegnate 1', 'Letti 1']);
      expect(tester.widget<PostinoMessageTile>(_rowOf('m2')).starred, isTrue, reason: 'its latest message has none');
    });

    testWidgets('j and k go over the headings, row after row', (tester) async {
      await _startSections(tester, starred: 2, read: 2);
      await tester.tap(_rowOf('s1'));
      await tester.pumpAndSettle();
      final seen = [_focusedId()];
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
        await tester.pumpAndSettle();
        seen.add(_focusedId());
      }
      expect(seen, ['s1', 's2', 'r1', 'r2']);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();
      expect(_focusedId(), 'r1');
    });

    testWidgets('the focus rule: the open Conversazione stays in Da leggere once read, and moves when the focus does', (
      tester,
    ) async {
      await _startSections(tester, unread: 2, read: 1);
      await tester.tap(_rowOf('u1'));
      await tester.pumpAndSettle();
      expect(tester.widget<PostinoMessageTile>(_rowOf('u1')).unread, isFalse, reason: 'opening reads it');
      expect(_headings(tester), ['Da leggere 2', 'Letti 1'], reason: 'it keeps its section while open');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();
      expect(_focusedId(), 'u2');
      expect(_headings(tester), ['Da leggere 1', 'Letti 2'], reason: 'the focus moved on: it went to Letti');
      expect(_topOf(tester, _rowOf('u1')), greaterThan(_topOf(tester, _rowOf('u2'))));
    });

    testWidgets('a Conversazione without the focus changes section at once, animated', (tester) async {
      final p = await _startSections(tester, unread: 1, read: 2);
      await tester.tap(_rowOf('r1'));
      await tester.pumpAndSettle();
      // Read on another device: u1 is not the focused one.
      p.changeElsewhere('u1', readAttribute, true);
      await getIt<SyncEngine>().syncAll();
      await tester.pump();
      await tester.pump(PostinoMotion.swipeDismiss ~/ 2);
      expect(_rowOf('u1'), findsNWidgets(2), reason: 'it fades from Da leggere while it opens in Letti');
      await tester.pumpAndSettle();
      expect(_rowOf('u1'), findsOneWidget);
      expect(find.byType(PostinoSectionHeader), findsNothing, reason: 'Letti alone has no heading');
    });

    testWidgets('an Account inbox has the sections too, and its «Mostra tutti» is of that Account; an Etichetta none', (
      tester,
    ) async {
      final p = await _startSections(tester, starred: 4, read: 1);
      p.deliver(msg('e1', conversationId: 't-e1', labelIds: const ['Label_12'], isStarred: true));
      await getIt<SyncEngine>().syncAll();
      unawaited(Routefly.navigate(routePaths.posta.$accountId.path.changes({'accountId': 'a1'})));
      await tester.pumpAndSettle();
      expect(_headings(tester), ['Contrassegnate 4', 'Letti 1']);
      await tester.tap(find.widgetWithText(PostinoButton, 'Mostra tutti'));
      await tester.pumpAndSettle();
      final bar = tester.widget<PostinoAppBar>(find.byType(PostinoAppBar).last);
      expect((bar.title, bar.subtitle), ('Contrassegnate', 'a1@example.com'));
      final tile = find.descendant(of: find.byType(InboxSectionScreen), matching: _rowOf('s1'));
      expect(tester.widget<PostinoMessageTile>(tile).account, isNull, reason: 'one Account: no mark');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      unawaited(Routefly.navigate(labelPath('a1', 'Label_12')));
      await tester.pumpAndSettle();
      expect(_rowOf('e1'), findsOneWidget);
      expect(find.byType(PostinoSectionHeader), findsNothing);
    });

    testWidgets('«Mostra tutti» opens the whole section over the posta; Esc and Indietro close it', (tester) async {
      await _startSections(tester, unread: 5, read: 1);
      await tester.tap(find.widgetWithText(PostinoButton, 'Mostra tutti'));
      await tester.pumpAndSettle();
      expect(find.byType(InboxSectionScreen), findsOneWidget);
      final bar = tester.widget<PostinoAppBar>(find.byType(PostinoAppBar).last);
      expect((bar.title, bar.subtitle), ('Da leggere', 'tutti'));
      final tile = find.descendant(of: find.byType(InboxSectionScreen), matching: _rowOf('u1'));
      expect(
        tester.widget<PostinoMessageTile>(tile).account,
        isNotNull,
        reason: 'Accounts mix: each row marks its own',
      );
      for (var i = 1; i <= 5; i++) {
        expect(find.descendant(of: find.byType(InboxSectionScreen), matching: _rowOf('u$i')), findsOneWidget);
      }
      expect(find.descendant(of: find.byType(InboxSectionScreen), matching: _rowOf('r1')), findsNothing);
      expect(
        find.descendant(of: find.byType(InboxSectionScreen), matching: find.byType(PostinoSectionHeader)),
        findsNothing,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(InboxSectionScreen), findsNothing);

      await tester.tap(find.widgetWithText(PostinoButton, 'Mostra tutti'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Indietro').last);
      await tester.pumpAndSettle();
      expect(find.byType(InboxSectionScreen), findsNothing);
    });

    testWidgets(
      'in the screen the open Conversazione stays while read, beside the list; Esc closes it, then the screen',
      (tester) async {
        await _startSections(tester, unread: 4);
        await tester.tap(find.widgetWithText(PostinoButton, 'Mostra tutti'));
        await tester.pumpAndSettle();
        final inScreen = find.descendant(of: find.byType(InboxSectionScreen), matching: _rowOf('u2'));
        await tester.tap(inScreen);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: find.byType(InboxSectionScreen), matching: find.byType(PostinoThreadView)),
          findsOne,
        );
        expect(inScreen, findsOneWidget, reason: 'read now, it keeps the focus and its section');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(InboxSectionScreen), findsOneWidget, reason: 'the first Esc closes the Conversazione only');
        expect(
          find.descendant(of: find.byType(InboxSectionScreen), matching: find.byType(PostinoThreadView)),
          findsNothing,
        );
        expect(inScreen, findsOneWidget, reason: 'its row has the focus still');
        await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
        await tester.pumpAndSettle();
        expect(inScreen, findsNothing, reason: 'the focus left it: it is in Letti now');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(InboxSectionScreen), findsOneWidget, reason: 'j opened the next one: Esc closes it');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(InboxSectionScreen), findsNothing, reason: 'the second Esc leaves the screen');
      },
    );

    testWidgets('in the screen the system Indietro closes the open Conversazione first, then the screen', (
      tester,
    ) async {
      await _startSections(tester, unread: 4);
      await tester.tap(find.widgetWithText(PostinoButton, 'Mostra tutti'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(InboxSectionScreen), matching: _rowOf('u2')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(InboxSectionScreen), findsOneWidget);
      expect(
        find.descendant(of: find.byType(InboxSectionScreen), matching: find.byType(PostinoThreadView)),
        findsNothing,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(InboxSectionScreen), findsNothing);
    });

    testWidgets('on a narrow window the Conversazione closed gets its row back, which moves on the next move', (
      tester,
    ) async {
      await _startSections(tester, unread: 2, read: 1, width: 800);
      await tester.tap(_rowOf('u1'));
      await tester.pumpAndSettle();
      expect(find.byType(PostinoThreadView), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PostinoThreadView), findsNothing);
      expect(_headings(tester), ['Da leggere 2', 'Letti 1'], reason: 'read now, it waits for the focus back');
      expect(_focusedId(), 'u1');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();
      expect(_focusedId(), 'u2');
      expect(_headings(tester), ['Da leggere 1', 'Letti 2'], reason: 'the focus moved on: it went to Letti');
    });

    testWidgets('the open Conversazione stays shown when newer ones arrive in its section; j goes on from it', (
      tester,
    ) async {
      final p = await _startSections(tester, unread: 3, read: 1);
      await tester.tap(_rowOf('u3'));
      await tester.pumpAndSettle();
      p.deliver(msg('n1', subject: 'Nuova', date: DateTime.utc(2026, 10, 1, 10), conversationId: 't-n1'));
      await getIt<SyncEngine>().syncAll();
      await tester.pumpAndSettle();
      expect(_headings(tester), ['Da leggere 4', 'Letti 1']);
      expect(_rowOf('u3'), findsOneWidget, reason: 'it takes the place of the third');
      expect(_rowOf('u2'), findsNothing);
      expect(tester.widget<PostinoMessageTile>(_rowOf('u3')).selected, isTrue);
      expect(_focusedId(), 'u3');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();
      expect(_focusedId(), 'r1');
      expect(_rowOf('u3'), findsOneWidget, reason: 'read, it went to Letti');
      expect(_headings(tester), ['Da leggere 3', 'Letti 2']);
    });

    testWidgets('a row held by the keyboard focus moves as soon as the focus leaves it', (tester) async {
      await _startSections(tester, unread: 4, read: 1, width: 800);
      final row = find.descendant(of: _rowOf('u1'), matching: find.byType(PostinoFocusRing));
      Focus.of(tester.element(row)).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      // The Stella is written to the database: real I/O, no time passes on the test's clock.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(pumpEventQueue);
      }
      expect(tester.widget<PostinoMessageTile>(_rowOf('u1')).starred, isTrue);
      expect(_headings(tester), ['Da leggere 4', 'Letti 1'], reason: 'focused, it keeps its section');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_focusedId(), isNot('u1'));
      expect(_headings(tester), [
        'Da leggere 4',
        'Letti 1',
      ], reason: 'the focus left it: still unread, so still in Da leggere (the Stella does not win)');
    });

    testWidgets('a row held by the keyboard focus stays while its menu is open, whatever the sync says', (
      tester,
    ) async {
      final p = await _startSections(tester, unread: 4, read: 1, width: 800);
      final row = find.descendant(of: _rowOf('u1'), matching: find.byType(PostinoFocusRing));
      Focus.of(tester.element(row)).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();
      expect(_focusedId(), isNull, reason: 'the focus is in the menu');
      // Starred on another device while its menu is open.
      p.changeElsewhere('u1', starredAttribute, true);
      await getIt<SyncEngine>().syncAll();
      await tester.pumpAndSettle();
      expect(tester.widget<PostinoMessageTile>(_rowOf('u1')).starred, isTrue);
      expect(_headings(tester), ['Da leggere 4', 'Letti 1'], reason: 'its menu is open: it keeps its section');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_focusedId(), 'u1', reason: 'the menu gives the focus back');
      expect(_headings(tester), ['Da leggere 4', 'Letti 1']);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_headings(tester), ['Da leggere 4', 'Letti 1'], reason: 'the focus left it: still unread');
    });

    testWidgets('«Mostra tutti» is reached with Tab from the cursor row and opens with Invio or Spazio', (
      tester,
    ) async {
      await _startSections(tester, starred: 1, unread: 4);
      for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
        final row = find.descendant(of: _rowOf('s1'), matching: find.byType(PostinoFocusRing));
        Focus.of(tester.element(row)).requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final focused = FocusManager.instance.primaryFocus!.context!;
        expect(focused.findAncestorWidgetOfExactType<PostinoSectionHeader>()?.title, 'Da leggere');
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(find.byType(InboxSectionScreen), findsOneWidget, reason: '$key');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(InboxSectionScreen), findsNothing);
      }
    });

    testWidgets('j and k over a heading in a list taller than the screen keep the row reached visible and focused', (
      tester,
    ) async {
      await _startSections(tester, starred: 3, read: 30, width: 800);
      final row = find.descendant(of: _rowOf('s1'), matching: find.byType(PostinoFocusRing));
      Focus.of(tester.element(row)).requestFocus();
      await tester.pumpAndSettle();
      final list = tester.getRect(find.byType(MessageList));
      void visible(String id) {
        expect(_focusedId(), id);
        final r = tester.getRect(_rowOf(id));
        expect(r.top, greaterThanOrEqualTo(list.top - 0.5), reason: id);
        expect(r.bottom, lessThanOrEqualTo(list.bottom + 0.5), reason: id);
      }

      for (final id in ['s2', 's3', for (var i = 1; i <= 30; i++) 'r$i']) {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
        await tester.pumpAndSettle();
        visible(id);
      }
      for (final id in [for (var i = 29; i >= 1; i--) 'r$i', 's3', 's2']) {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.pumpAndSettle();
        visible(id);
      }
    });
  });
}
