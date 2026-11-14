// The list of Conversazioni (the twin of message_list.dart for the mutation test): the cursor follows a focus that
// came some other way, the number of rows is reported when it changes, and rows leave and arrive animated (#282).
import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/design_system/design_system.dart';
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
    p.deliver(msg('m$i', subject: 'Fattura $i', date: DateTime.utc(2026, 10, 1, 9, i), conversationId: 't$i'));
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

Future<void> _removeRemotely(WidgetTester tester, FakeMailProvider p, Iterable<int> ids) async {
  for (final i in ids) {
    p.removeRemotely('m$i');
  }
  await getIt<SyncEngine>().syncAll();
  await tester.pumpAndSettle();
}

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
    p.deliver(msg('m9', subject: 'Nuova', date: DateTime.utc(2026, 10, 2), conversationId: 't9'));
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
      p.deliver(msg('m9', subject: 'Nuova', date: DateTime.utc(2026, 10, 2), conversationId: 't9'));
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
          for (final f in tester.widgetList<PostinoSizeFade>(find.byType(PostinoSizeFade))) {
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
      p.deliver(msg('m9', subject: 'Nuova', date: DateTime.utc(2026, 10, 2), conversationId: 't9'));
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
        ..deliver(msg('m9', subject: 'Nuova', date: DateTime.utc(2026, 10, 2), conversationId: 't9'));
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

    testWidgets('a row that comes back while leaving turns round', (tester) async {
      final p = await _start(tester);
      p.removeRemotely('m3');
      await _syncNoSettle(tester);
      await tester.pump(PostinoMotion.swipeDismiss ~/ 2);
      final out = _visible(tester, 3).opacity;
      p.deliver(msg('m3', subject: 'Fattura 3', date: DateTime.utc(2026, 10, 1, 9, 3), conversationId: 't3'));
      await _syncNoSettle(tester);
      await tester.pump(PostinoMotion.rowEnter ~/ 4);
      expect(_visible(tester, 3).opacity, greaterThan(out));
      await tester.pumpAndSettle();
      expect(_visible(tester, 3), (opacity: 1.0, height: 1.0));
    });
  });
}
