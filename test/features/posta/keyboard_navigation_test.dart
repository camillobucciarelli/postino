// Keyboard navigation (#54, ADR 0014): arrows and j/k in the list, Enter and Esc, one Tab stop,
// focus = selection, scrolling, j/k in the Conversazione, layout changes, text fields, the registry.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/features/posta/presentation/posta_shortcuts.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _desktop = Size(1600, 900);
const _narrow = Size(800, 800);
const _phone = Size(390, 844);

/// Rows `m1` to `mN`, newest first: `mN` is the first row.
Future<FakeMailProvider> _start(
  WidgetTester tester,
  Size size, {
  int n = 5,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  final p = await h.addAccount('a1');
  for (var i = 1; i <= n; i++) {
    p.deliver(
      msg(
        'm$i',
        subject: 'Oggetto $i',
        date: DateTime.utc(2026, 10, 1, 9, i),
        conversationId: 't$i',
      ),
    );
  }
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  // Routefly keeps the last navigation in statics.
  Routefly.navigate(routePaths.posta.path);
  await tester.pumpAndSettle();
  return p;
}

Finder _row(int i) => find.byKey(ValueKey('row-a1-m$i'), skipOffstage: false);
Finder _conversation(int i) =>
    find.byKey(ValueKey('conversation-a1/t$i'), skipOffstage: false);

PostinoMessageTile _tile(WidgetTester tester, int i) =>
    tester.widget<PostinoMessageTile>(_row(i));

/// The number of the row that has the focus, null when focus is elsewhere.
int? _focusedRow() {
  final key = FocusManager.instance.primaryFocus?.context
      ?.findAncestorWidgetOfExactType<PostinoMessageTile>()
      ?.key;
  return key is ValueKey<String> ? int.parse(key.value.split('-m').last) : null;
}

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pumpAndSettle();
}

Future<void> _tapRow(WidgetTester tester, int i) async {
  await tester.tap(_row(i));
  await tester.pumpAndSettle();
}

/// Moves the focus inside the open Conversazione.
Future<void> _focusConversation(WidgetTester tester, int i) async {
  Focus.of(
    tester.element(
      find
          .descendant(
            of: _conversation(i),
            matching: find.byType(PostinoFocusRing),
          )
          .first,
    ),
  ).requestFocus();
  await tester.pump();
}

/// Whether the focus is inside the open Conversazione [i].
bool _focusInConversation(WidgetTester tester, int i) {
  final ctx = FocusManager.instance.primaryFocus?.context;
  return ctx != null &&
      ctx.findAncestorWidgetOfExactType<ConversationView>()?.conversationId ==
          't$i';
}

Finder get _backButton => find.descendant(
  of: find.byType(ConversationView),
  matching: find.byWidgetPredicate(
    (w) => w is PostinoIcon && w.icon == PostinoIcons.arrowLeft,
  ),
);

bool _focusOnBackButton(WidgetTester tester) {
  final ctx = FocusManager.instance.primaryFocus?.context;
  return ctx != null &&
      find
          .descendant(
            of: find.byElementPredicate((e) => e == ctx),
            matching: find.byType(PostinoIcon),
          )
          .evaluate()
          .isNotEmpty &&
      ctx.findAncestorWidgetOfExactType<ConversationView>() != null;
}

void main() {
  group('review fixes', () {
    testWidgets(
      'scrolling a fresh list with the mouse keeps the list reachable with Tab',
      (tester) async {
        await _start(tester, _phone, n: 40);
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(_row(39), findsNothing);
        for (var i = 0; i < 10 && _focusedRow() == null; i++) {
          await _press(tester, LogicalKeyboardKey.tab);
        }
        expect(_focusedRow(), 40);
      },
    );

    testWidgets('Tab into the list then j / arrow goes to the second row', (
      tester,
    ) async {
      await _start(tester, _desktop);
      for (var i = 0; i < 10 && _focusedRow() == null; i++) {
        await _press(tester, LogicalKeyboardKey.tab);
      }
      expect(_focusedRow(), 5);
      await _press(tester, LogicalKeyboardKey.keyJ);
      expect(_focusedRow(), 4);
      expect(_conversation(4), findsOneWidget);
      expect(_conversation(5), findsNothing);
    });

    testWidgets('one pane: Tab then arrow down moves the focus at once', (
      tester,
    ) async {
      await _start(tester, _phone);
      for (var i = 0; i < 10 && _focusedRow() == null; i++) {
        await _press(tester, LogicalKeyboardKey.tab);
      }
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedRow(), 4);
    });

    testWidgets(
      'the cursor row disappears from the list: the list stays a Tab stop and Esc focuses a row that exists',
      (tester) async {
        final p = await _start(tester, _desktop);
        await _tapRow(tester, 3);
        p.removeRemotely('m3');
        await getIt<SyncEngine>().syncAll();
        await tester.pumpAndSettle();
        expect(_row(3), findsNothing);
        await _press(tester, LogicalKeyboardKey.escape);
        expect(_focusedRow(), 2);
        await _press(tester, LogicalKeyboardKey.tab, shift: true);
        expect(_focusedRow(), isNull);
        await _press(tester, LogicalKeyboardKey.tab);
        expect(_focusedRow(), 2);
      },
    );

    for (final (name, row, key) in [
      ('last', 1, LogicalKeyboardKey.keyJ),
      ('first', 5, LogicalKeyboardKey.keyK),
    ]) {
      testWidgets('one pane, $name Conversazione open: $key does nothing', (
        tester,
      ) async {
        await _start(tester, _phone);
        await _tapRow(tester, row);
        expect(_focusOnBackButton(tester), isTrue);
        await _press(tester, key);
        expect(_conversation(row), findsOneWidget);
        expect(_focusOnBackButton(tester), isTrue);
        await _press(tester, LogicalKeyboardKey.enter);
        expect(find.byType(ConversationView), findsNothing);
        expect(_focusedRow(), row);
      });
    }
  });

  group('back button', () {
    testWidgets('two panes show none; Esc still closes the Conversazione', (
      tester,
    ) async {
      await _start(tester, _desktop);
      await _tapRow(tester, 3);
      expect(find.byType(ConversationView), findsOneWidget);
      expect(_backButton, findsNothing);
      await _press(tester, LogicalKeyboardKey.keyJ);
      expect(_backButton, findsNothing);
      await _press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ConversationView), findsNothing);
      expect(_focusedRow(), 2);
    });

    testWidgets(
      'one pane shows it and focuses it on opening; it follows the window size',
      (tester) async {
        await _start(tester, _narrow);
        await _tapRow(tester, 3);
        expect(_backButton, findsOneWidget);
        expect(_focusOnBackButton(tester), isTrue);

        tester.view.physicalSize = _desktop;
        await tester.pumpAndSettle();
        expect(_backButton, findsNothing);
        expect(_focusedRow(), 3);
        expect(_conversation(3), findsOneWidget);
        // Nothing odd without the button: j / k and arrows still work.
        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_conversation(2), findsOneWidget);
        expect(_focusedRow(), 2);

        tester.view.physicalSize = _narrow;
        await tester.pumpAndSettle();
        expect(_backButton, findsOneWidget);
        expect(_focusOnBackButton(tester), isTrue);
        await _press(tester, LogicalKeyboardKey.enter);
        expect(find.byType(ConversationView), findsNothing);
        expect(_focusedRow(), 2);
      },
    );

    testWidgets(
      'narrowed with the Conversazione scrolled into a long message, the focus goes to Indietro',
      (tester) async {
        final p = await _start(tester, _desktop);
        for (var i = 0; i < 3; i++) {
          p.deliver(
            msg(
              'x$i',
              subject: 'Oggetto 3',
              date: DateTime.utc(2026, 10, 1, 9, 3, i + 1),
              conversationId: 't3',
            ),
          );
        }
        await tester.pumpAndSettle();
        p.bodies['x2'] = MessageBody(
          List.generate(200, (i) => 'Riga $i').join('\n'),
          BodyKind.testo,
        );
        await tester.tap(find.byKey(const ValueKey('row-a1-x2')));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -1500));
        await tester.pumpAndSettle();

        tester.view.physicalSize = _narrow;
        await tester.pumpAndSettle();
        expect(_backButton, findsOneWidget);
        expect(
          find.descendant(
            of: find.byElementPredicate(
              (e) => e == FocusManager.instance.primaryFocus?.context,
            ),
            matching: find.byWidgetPredicate(
              (w) => w is PostinoIcon && w.icon == PostinoIcons.arrowLeft,
            ),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('two panes', () {
    testWidgets(
      'arrow down / j open the next Conversazione, focus it and mark it read; arrow up / k the previous',
      (tester) async {
        await _start(tester, _desktop);
        await _tapRow(tester, 5);
        for (final (key, to) in [
          (LogicalKeyboardKey.arrowDown, 4),
          (LogicalKeyboardKey.keyJ, 3),
          (LogicalKeyboardKey.arrowUp, 4),
          (LogicalKeyboardKey.keyK, 5),
        ]) {
          final first = to <= 3;
          if (first) expect(_tile(tester, to).unread, isTrue);
          await _press(tester, key);
          expect(_conversation(to), findsOneWidget, reason: '$key');
          expect(_tile(tester, to).selected, isTrue);
          expect(_focusedRow(), to);
          expect(_tile(tester, to).unread, isFalse, reason: 'read by $key');
        }
      },
    );

    testWidgets('after Esc the arrows go on from the row just closed', (
      tester,
    ) async {
      await _start(tester, _desktop);
      await _tapRow(tester, 5);
      await _press(tester, LogicalKeyboardKey.escape);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_conversation(4), findsOneWidget);
    });
  });

  group('one pane', () {
    testWidgets(
      'arrows move the focus without opening; Enter opens; Esc goes back to the row just closed',
      (tester) async {
        await _start(tester, _phone);
        await _tapRow(tester, 4);
        await _press(tester, LogicalKeyboardKey.escape);
        expect(_focusedRow(), 4);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.keyJ);
        expect(_focusedRow(), 2);
        await _press(tester, LogicalKeyboardKey.arrowUp);
        expect(_focusedRow(), 3);
        expect(find.byType(ConversationView), findsNothing);
        expect(_tile(tester, 4).unread, isFalse);
        expect(_tile(tester, 3).unread, isTrue);

        await _press(tester, LogicalKeyboardKey.enter);
        expect(_conversation(3), findsOneWidget);
        await _press(tester, LogicalKeyboardKey.escape);
        expect(find.byType(ConversationView), findsNothing);
        expect(_focusedRow(), 3);
      },
    );

    testWidgets('the AppBar back button also returns to the row just closed', (
      tester,
    ) async {
      await _start(tester, _phone);
      await _tapRow(tester, 2);
      await tester.tap(
        find
            .descendant(
              of: find.byType(ConversationView),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ConversationView), findsNothing);
      expect(_focusedRow(), 2);
    });
  });

  group('one pane, opening', () {
    testWidgets(
      'Enter, a click and j / k put the focus in the Conversazione; Esc and back return to the row, and the arrows work again',
      (tester) async {
        await _start(tester, _phone);
        await _tapRow(tester, 4);
        expect(_focusInConversation(tester, 4), isTrue, reason: 'click');
        await _press(tester, LogicalKeyboardKey.keyJ);
        expect(_focusInConversation(tester, 3), isTrue, reason: 'j');
        await _press(tester, LogicalKeyboardKey.escape);
        expect(_focusedRow(), 3);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focusedRow(), 2);
        await _press(tester, LogicalKeyboardKey.enter);
        expect(_focusInConversation(tester, 2), isTrue, reason: 'Enter');
        await tester.tap(
          find
              .descendant(
                of: find.byType(ConversationView),
                matching: find.byType(InkWell),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(_focusedRow(), 2);
        await _press(tester, LogicalKeyboardKey.arrowUp);
        expect(_focusedRow(), 3);
      },
    );
  });

  group('one cursor, one Tab stop', () {
    testWidgets(
      'a click focuses the row; Tab from the bar lands on it; a second Tab leaves the list',
      (tester) async {
        await _start(tester, _desktop);
        await _tapRow(tester, 3);
        expect(_focusedRow(), 3);
        expect(_tile(tester, 3).selected, isTrue);

        await _press(tester, LogicalKeyboardKey.tab, shift: true);
        expect(_focusedRow(), isNull);
        await _press(tester, LogicalKeyboardKey.tab);
        expect(_focusedRow(), 3);
        await _press(tester, LogicalKeyboardKey.tab);
        expect(_focusedRow(), isNull);
        expect(FocusManager.instance.primaryFocus?.context, isNotNull);
      },
    );

    testWidgets('with no selection Tab enters the list on the first row', (
      tester,
    ) async {
      await _start(tester, _phone);
      for (var i = 0; i < 10 && _focusedRow() == null; i++) {
        await _press(tester, LogicalKeyboardKey.tab);
      }
      expect(_focusedRow(), 5);
    });

    testWidgets('focus and selection never sit on different rows', (
      tester,
    ) async {
      await _start(tester, _desktop);
      await _tapRow(tester, 5);
      for (final k in [
        LogicalKeyboardKey.keyJ,
        LogicalKeyboardKey.keyJ,
        LogicalKeyboardKey.keyK,
      ]) {
        await _press(tester, k);
        final selected = [
          for (var i = 1; i <= 5; i++)
            if (_tile(tester, i).selected) i,
        ];
        expect(selected, [_focusedRow()]);
      }
      await _tapRow(tester, 1);
      expect(_focusedRow(), 1);
    });
  });

  group('scrolling', () {
    double top(WidgetTester tester, int i) => tester.getTopLeft(_row(i)).dy;
    bool visible(WidgetTester tester, int i) {
      final r = tester.getRect(_row(i));
      final list = tester.getRect(find.byType(ListView));
      return r.top >= list.top - 0.5 && r.bottom <= list.bottom + 0.5;
    }

    testWidgets(
      'arrow down up to the last row of a list longer than the screen keeps it visible, and so does going back up',
      (tester) async {
        await _start(tester, _phone, n: 40);
        await _tapRow(tester, 40);
        await _press(tester, LogicalKeyboardKey.escape);
        for (var i = 39; i >= 1; i--) {
          await _press(tester, LogicalKeyboardKey.arrowDown);
          expect(_focusedRow(), i);
          expect(visible(tester, i), isTrue, reason: 'row $i going down');
        }
        for (var i = 2; i <= 40; i++) {
          await _press(tester, LogicalKeyboardKey.arrowUp);
          expect(_focusedRow(), i);
          expect(visible(tester, i), isTrue, reason: 'row $i going up');
        }
        expect(top(tester, 40), greaterThanOrEqualTo(0));
      },
    );

    testWidgets('a row scrolled out of the screen is brought back', (
      tester,
    ) async {
      await _start(tester, _phone, n: 40);
      await _tapRow(tester, 40);
      await _press(tester, LogicalKeyboardKey.escape);
      await tester.drag(find.byType(ListView), const Offset(0, -6000));
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.keyJ);
      expect(_focusedRow(), 39);
      expect(visible(tester, 39), isTrue);
    });
  });

  group('Conversazione', () {
    for (final (name, size) in [
      ('two panes', _desktop),
      ('one pane', _phone),
    ]) {
      testWidgets('j / k open the next / previous ($name)', (tester) async {
        await _start(tester, size);
        await _tapRow(tester, 3);
        await _focusConversation(tester, 3);
        await _press(tester, LogicalKeyboardKey.keyJ);
        expect(_conversation(2), findsOneWidget);
        expect(_conversation(3), findsNothing);
        expect(_tile(tester, 2).unread, isFalse);
        await _focusConversation(tester, 2);
        await _press(tester, LogicalKeyboardKey.keyK);
        await _press(tester, LogicalKeyboardKey.keyK);
        expect(_conversation(4), findsOneWidget);
        // Back to the row of the Conversazione being read.
        await _press(tester, LogicalKeyboardKey.escape);
        expect(_focusedRow(), 4);
      });
    }

    testWidgets('the arrows do not leave the Conversazione', (tester) async {
      await _start(tester, _desktop);
      await _tapRow(tester, 3);
      await _focusConversation(tester, 3);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_conversation(3), findsOneWidget);
    });
  });

  group('layout change', () {
    testWidgets(
      'widening moves the focus to the selected row with the Conversazione still open; shrinking moves it to the Conversazione',
      (tester) async {
        await _start(tester, _narrow);
        await _tapRow(tester, 3);
        expect(_conversation(3), findsOneWidget);
        await _focusConversation(tester, 3);
        expect(_focusedRow(), isNull);

        tester.view.physicalSize = _desktop;
        await tester.pumpAndSettle();
        expect(_focusedRow(), 3);
        expect(_tile(tester, 3).selected, isTrue);
        expect(_conversation(3), findsOneWidget);

        tester.view.physicalSize = _narrow;
        await tester.pumpAndSettle();
        expect(_focusedRow(), isNull);
        expect(_focusInConversation(tester, 3), isTrue);
        expect(_conversation(3), findsOneWidget);
      },
    );
  });

  group('text fields', () {
    testWidgets('j / k typed in a text field do not navigate', (tester) async {
      final cursor = ListCursor();
      final moves = <int>[];
      cursor.move = moves.add;
      final bubbled = <LogicalKeyboardKey>[];
      final field = FocusNode();
      final other = FocusNode();
      addTearDown(field.dispose);
      addTearDown(other.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Focus(
              onKeyEvent: (_, e) {
                if (e is KeyDownEvent) bubbled.add(e.logicalKey);
                return KeyEventResult.ignored;
              },
              child: PostaShortcuts(
                cursor: cursor,
                child: Column(
                  children: [
                    TextField(focusNode: field),
                    Focus(focusNode: other, child: const SizedBox()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      field.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      expect(moves, isEmpty);
      expect(bubbled, [LogicalKeyboardKey.keyJ, LogicalKeyboardKey.keyK]);

      other.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      expect(moves, [1, -1]);
    });
  });

  test('the registry has no two actions on the same key', () {
    final keys = postaShortcuts.map((s) => (s.key, s.command)).toList();
    expect(keys.toSet().length, keys.length);
    expect(
      postaShortcuts.map((s) => s.action).toSet(),
      containsAll(PostaAction.values),
    );
  });
}
