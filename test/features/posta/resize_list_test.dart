// The resizable list (#62): drag, double click, limits, preferred vs shown width, keyboard, semantics, saving.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/settings_repository.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

class _FakeSettings implements SettingsRepository {
  _FakeSettings([this.saved]);
  double? saved;
  final writes = <double>[];

  @override
  Future<double?> listWidth() async => saved;

  @override
  Future<void> setListWidth(double width) async {
    saved = width;
    writes.add(width);
  }

  @override
  Future<bool?> sidebarExpanded() async => null;

  @override
  Future<void> setSidebarExpanded({required bool? expanded}) async {}
}

Future<_FakeSettings> _start(WidgetTester tester, double width, {double? stored}) async {
  tester.view
    ..physicalSize = Size(width, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  (await h.addAccount('a1'))
    ..deliver(msg('x', subject: 'Da uno'))
    ..deliver(msg('y', subject: 'Da due'));
  final settings = _FakeSettings(stored);
  getIt
    ..unregister<SettingsRepository>()
    ..registerSingleton<SettingsRepository>(settings);
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  return settings;
}

Future<void> _resize(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  await tester.pumpAndSettle();
}

final _handle = find.byType(PostinoResizeHandle);

/// The width of the pane that holds the list.
double _listWidth(WidgetTester tester) =>
    tester.getTopLeft(_handle).dx - tester.getTopLeft(find.byType(PostinoListDetailLayout)).dx;

Future<void> _drag(WidgetTester tester, double dx) async {
  await tester.drag(_handle, Offset(dx, 0));
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _focusHandle(WidgetTester tester) async {
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  Focus.of(tester.element(find.descendant(of: _handle, matching: find.byType(PostinoFocusRing)))).requestFocus();
  await tester.pump();
}

bool _handleFocused() => primaryFocus?.context?.findAncestorWidgetOfExactType<PostinoResizeHandle>() != null;

void main() {
  test('the shown width is the preferred one limited to the window, the minimum wins', () {
    expect(shownListWidth(700, 1600), 700);
    expect(shownListWidth(700, 1000), 500);
    expect(shownListWidth(100, 1600), 280);
    expect(shownListWidth(380, 500), 280);
    expect(shownListWidth(900, 500), 280);
  });

  group('the divider exists only with two panes', () {
    for (final (w, there) in [(899.0, false), (900.0, true), (1200.0, true)]) {
      testWidgets('at ${w.toInt()}: $there', (tester) async {
        await _start(tester, w);
        expect(_handle, there ? findsOneWidget : findsNothing);
      });
    }
  });

  group('drag', () {
    testWidgets('moves the list live and stops at 280', (tester) async {
      await _start(tester, 1200);
      expect(_listWidth(tester), PostinoSize.listWidth);
      await _drag(tester, 100);
      // The touch slop is not part of the drag.
      expect(_listWidth(tester), inInclusiveRange(440, 480));
      await _drag(tester, -500);
      expect(_listWidth(tester), 280);
    });

    for (final (w, max) in [(1200.0, 600.0), (1600.0, 800.0)]) {
      testWidgets('stops at half of a ${w.toInt()} window: ${max.toInt()}', (tester) async {
        await _start(tester, w);
        await _drag(tester, 2000);
        expect(_listWidth(tester), max);
      });
    }

    testWidgets('writes once, at the end', (tester) async {
      final s = await _start(tester, 1200);
      final g = await tester.startGesture(tester.getCenter(_handle));
      await g.moveBy(const Offset(40, 0));
      await tester.pump();
      await g.moveBy(const Offset(40, 0));
      await tester.pump();
      final w = _listWidth(tester);
      expect(w, greaterThan(380));
      expect(s.writes, isEmpty);
      await g.up();
      await tester.pumpAndSettle();
      expect(s.writes, [w]);
    });

    testWidgets('shows the horizontal resize cursor', (tester) async {
      await _start(tester, 1200);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(_handle));
      await tester.pump();
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.resizeLeftRight);
    });
  });

  testWidgets('double click goes back to 380 and saves it', (tester) async {
    final s = await _start(tester, 1200, stored: 500);
    expect(_listWidth(tester), 500);
    await tester.tap(_handle);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(_handle);
    await tester.pumpAndSettle();
    expect(_listWidth(tester), 380);
    expect(s.writes, [380]);
  });

  testWidgets('a narrow window limits the shown width, not the preference', (tester) async {
    final s = await _start(tester, 1600, stored: 700);
    expect(_listWidth(tester), 700);
    await _resize(tester, 1000);
    expect(_listWidth(tester), 500);
    await _resize(tester, 1600);
    expect(_listWidth(tester), 700);
    expect(s.saved, 700);
    expect(s.writes, isEmpty);
  });

  testWidgets('a drag back to where it began frees the live width', (tester) async {
    final s = await _start(tester, 1000, stored: 700);
    expect(_listWidth(tester), 500);
    final g = await tester.startGesture(tester.getCenter(_handle));
    await g.moveBy(const Offset(-100, 0));
    await tester.pump();
    await g.moveBy(const Offset(400, 0));
    await tester.pump();
    expect(_listWidth(tester), 500);
    await g.up();
    await tester.pumpAndSettle();
    await _resize(tester, 1600);
    expect(_listWidth(tester), 700);
    expect(s.writes, isEmpty);
    expect(s.saved, 700);
  });

  testWidgets('a click on the divider keeps the width set from the keyboard', (tester) async {
    final s = await _start(tester, 1200);
    await _drag(tester, 100);
    await _focusHandle(tester);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    final w = _listWidth(tester);
    final writes = s.writes.length;
    await tester.tap(_handle);
    await tester.pumpAndSettle();
    expect(_listWidth(tester), w);
    expect(s.saved, w);
    expect(s.writes.length, writes);
  });

  testWidgets('the width survives switching list', (tester) async {
    final s = await _start(tester, 1200);
    await _drag(tester, 100);
    final w = _listWidth(tester);
    expect(w, isNot(380));
    expect(s.saved, w);
    unawaited(Routefly.navigate(routePaths.posta.$accountId.path.changes({'accountId': 'a1'})));
    await tester.pumpAndSettle();
    expect(_listWidth(tester), w);
  });

  group('persistence', () {
    testWidgets('starts at the saved width, limited to the window', (tester) async {
      await _start(tester, 1200, stored: 450);
      expect(_listWidth(tester), 450);
    });

    testWidgets('starts at 380 with nothing saved', (tester) async {
      await _start(tester, 1200);
      expect(_listWidth(tester), 380);
    });
  });

  group('keyboard', () {
    testWidgets('Tab reaches the divider between the list and the Conversazione', (tester) async {
      await _start(tester, 1200);
      await tester.tap(find.text('Da uno'));
      await tester.pumpAndSettle();
      Focus.of(tester.element(find.text('Da uno').first)).requestFocus();
      var reached = false;
      for (var i = 0; i < 40 && !reached; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        reached = _handleFocused();
      }
      expect(reached, isTrue);
      // The next stop is inside the Conversazione, not back in the list.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_handleFocused(), isFalse);
      expect(tester.getTopLeft(find.byType(PostinoThreadView)).dx, greaterThan(tester.getTopLeft(_handle).dx));
    });

    testWidgets('arrows move by 16, Home and End go to the limits and stay there', (tester) async {
      final s = await _start(tester, 1200);
      await _focusHandle(tester);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_listWidth(tester), 396);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_listWidth(tester), 364);
      await _key(tester, LogicalKeyboardKey.home);
      expect(_listWidth(tester), 280);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_listWidth(tester), 280);
      await _key(tester, LogicalKeyboardKey.end);
      expect(_listWidth(tester), 600);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_listWidth(tester), 600);
      expect(s.saved, 600);
    });

    testWidgets('the arrows leave the open Conversazione alone', (tester) async {
      await _start(tester, 1200);
      await tester.tap(find.text('Da uno'));
      await tester.pumpAndSettle();
      final open = Routefly.currentUri;
      await _focusHandle(tester);
      for (final k in [
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowLeft,
      ]) {
        await _key(tester, k);
      }
      expect(Routefly.currentUri, open);
    });

    testWidgets('from a limited width the step starts at the shown width', (tester) async {
      final s = await _start(tester, 900, stored: 600);
      expect(_listWidth(tester), 450);
      await _focusHandle(tester);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_listWidth(tester), 434);
      expect(s.saved, 434);
    });
  });

  group('semantics', () {
    testWidgets('label, value, and increase and decrease by 16', (tester) async {
      final handle = tester.ensureSemantics();
      final s = await _start(tester, 1200);
      SemanticsNode node() => find.semantics.byAction(SemanticsAction.increase).evaluate().single;
      expect(node().label, 'Larghezza lista');
      expect(node().value, '380 pixel');
      expect(node().getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
      expect(node().getSemanticsData().hasAction(SemanticsAction.decrease), isTrue);
      tester.semantics.increase(find.semantics.byAction(SemanticsAction.increase));
      await tester.pumpAndSettle();
      expect(node().value, '396 pixel');
      expect(_listWidth(tester), 396);
      tester.semantics.decrease(find.semantics.byAction(SemanticsAction.increase));
      await tester.pumpAndSettle();
      tester.semantics.decrease(find.semantics.byAction(SemanticsAction.increase));
      await tester.pumpAndSettle();
      expect(node().value, '364 pixel');
      expect(s.saved, 364);
      handle.dispose();
    });

    testWidgets('increase and decrease respect the limits', (tester) async {
      final handle = tester.ensureSemantics();
      await _start(tester, 1200, stored: 280);
      final f = find.semantics.byAction(SemanticsAction.increase);
      tester.semantics.decrease(f);
      await tester.pumpAndSettle();
      expect(_listWidth(tester), 280);
      handle.dispose();
    });
  });
}
