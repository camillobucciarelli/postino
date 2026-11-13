// Testi della Conversazione selezionabili e copiabili (#69): una sola SelectionArea, Cmd/Ctrl+C e Cmd/Ctrl+A,
// l'intestazione (tap contro trascinamento), il doppio Esc, i link, j/k e Cmd/Ctrl+B, le etichette semantiche.

import 'dart:async';

import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

late Harness h;
String? _clipboard;

void _mockClipboard(WidgetTester tester) {
  _clipboard = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      _clipboard = (call.arguments as Map)['text'] as String?;
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

Future<void> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1600, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _mockClipboard(tester);
  h = await Harness.create();
  (await h.addAccount('a1'))
    ..bodies['h1'] = const MessageBody('Ciao Giulia', BodyKind.testo)
    ..deliver(
      msg(
        'h1',
        conversationId: 'h',
        from: 'ada@okafor-legal.it',
        fromName: 'Ada Okafor',
        to: const ['Giulia Ferri <a1@example.com>'],
        cc: const ['Marco Lenti <marco@example.com>'],
        subject: 'Contratto Rossi',
        date: DateTime.utc(2026, 10, 1, 9),
      ),
    )
    ..bodies['n1'] = const MessageBody(
      '<p>Vai al <a href="https://shop.example/offerte">negozio</a></p>',
      BodyKind.html,
    )
    ..deliver(
      msg('n1', conversationId: 'n', from: 'news@shop.example', subject: 'Offerte', date: DateTime.utc(2026, 10, 2, 9)),
    );
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('row-a1-$id')));
  await tester.pumpAndSettle();
}

Finder _text(String s) => find.textContaining(s, findRichText: true);
Finder get _conversation => find.byType(ConversationView);
Finder get _sender => find.descendant(
  of: _conversation,
  matching: find.byWidgetPredicate((w) => w is Text && (w.textSpan?.toPlainText() ?? '').startsWith('Ada')),
);

const _ctrl = LogicalKeyboardKey.controlLeft;

Future<void> _chord(WidgetTester tester, LogicalKeyboardKey mod, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(mod);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(mod);
  await tester.pumpAndSettle();
}

Future<void> _esc(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}

/// A mouse drag from [from] to [to].
Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await tester.pump();
  await g.moveTo(to);
  await tester.pump();
  await g.up();
  await tester.pumpAndSettle();
}

/// Clicks the body (the area takes the focus), then selects all.
Future<void> _selectAll(WidgetTester tester, LogicalKeyboardKey mod) async {
  await tester.tap(_text('Ciao Giulia'));
  await tester.pumpAndSettle();
  await _chord(tester, mod, LogicalKeyboardKey.keyA);
}

bool _expanded(WidgetTester tester) =>
    tester.widget<PostinoThreadMessage>(find.byType(PostinoThreadMessage).first).expanded;

void main() {
  for (final (name, platform, mod) in [
    ('Ctrl', TargetPlatform.windows, _ctrl),
    ('Cmd', TargetPlatform.macOS, LogicalKeyboardKey.metaLeft),
  ]) {
    testWidgets('$name+A stays in the Conversazione and $name+C copies it', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await _start(tester);
        await _open(tester, 'h1');
        await _selectAll(tester, mod);
        await _chord(tester, mod, LogicalKeyboardKey.keyC);

        final copied = _clipboard!;
        expect(copied, contains('Contratto Rossi'));
        expect(copied, contains('Ada Okafor'));
        expect(copied, contains('ada@okafor-legal.it'));
        expect(copied, contains('Ciao Giulia'));
        // Not the list, not the compact recipients, not the other Conversazione.
        expect(copied, isNot(contains('Offerte')));
        expect(copied, isNot(contains('news@shop.example')));
        expect(copied, isNot(contains('Marco')));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('the details are copiable, with their labels', (tester) async {
    await _start(tester);
    await _open(tester, 'h1');
    await tester.tap(_text('a me, cc'));
    await tester.pumpAndSettle();
    await _selectAll(tester, _ctrl);
    await _chord(tester, _ctrl, LogicalKeyboardKey.keyC);
    expect(_clipboard, contains('Marco Lenti <marco@example.com>'));
    expect(_clipboard, contains('Cc'));
  });

  group('header', () {
    testWidgets('a tap on the empty space or on the avatar collapses it', (tester) async {
      await _start(tester);
      await _open(tester, 'h1');
      expect(_expanded(tester), isTrue);
      final text = tester.getRect(_sender);
      await tester.tapAt(Offset(text.right + 40, text.center.dy));
      await tester.pumpAndSettle();
      expect(_expanded(tester), isFalse);

      await tester.tap(find.byType(PostinoAvatar).last);
      await tester.pumpAndSettle();
      expect(_expanded(tester), isTrue);
      await tester.tap(find.byType(PostinoAvatar).last);
      await tester.pumpAndSettle();
      expect(_expanded(tester), isFalse);
    });

    testWidgets('a drag over the text selects it without collapsing', (tester) async {
      await _start(tester);
      await _open(tester, 'h1');
      final text = tester.getRect(_sender);
      await _drag(tester, Offset(text.left + 1, text.center.dy), Offset(text.left + 60, text.center.dy));
      expect(_expanded(tester), isTrue);
      await _chord(tester, _ctrl, LogicalKeyboardKey.keyC);
      expect(_clipboard, isNotEmpty);
      expect('Ada Okafor ada@okafor-legal.it', contains(_clipboard!));
    });

    testWidgets('a double click selects a word, collapses nothing, opens no details', (tester) async {
      await _start(tester);
      await _open(tester, 'h1');
      final at = tester.getTopLeft(_sender) + const Offset(5, 8);
      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(_expanded(tester), isTrue);
      expect(find.text('Cc'), findsNothing);
    });
  });

  testWidgets('Esc: the first clears the selection, the second closes', (tester) async {
    await _start(tester);
    await _open(tester, 'h1');
    await _selectAll(tester, _ctrl);

    await _esc(tester);
    expect(_conversation, findsOneWidget);
    await _chord(tester, _ctrl, LogicalKeyboardKey.keyC);
    expect(_clipboard, isNull, reason: 'nothing left selected');

    await _esc(tester);
    expect(_conversation, findsNothing);
  });

  testWidgets('Esc with no selection closes at once', (tester) async {
    await _start(tester);
    await _open(tester, 'h1');
    await _esc(tester);
    expect(_conversation, findsNothing);
  });

  testWidgets('a link in the body is still tappable', (tester) async {
    await _start(tester);
    await _open(tester, 'n1');
    await tester.tapOnText(find.textRange.ofSubstring('negozio'));
    expect(h.links.opened, [Uri.parse('https://shop.example/offerte')]);
  });

  testWidgets('k and Ctrl+B work with a selection', (tester) async {
    await _start(tester);
    await _open(tester, 'h1');
    await _selectAll(tester, _ctrl);

    final bar = find.byType(PostinoNavigationDrawer);
    final before = tester.getSize(bar).width;
    await _chord(tester, _ctrl, LogicalKeyboardKey.keyB);
    expect(tester.getSize(bar).width, isNot(before));

    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-a1/n'), skipOffstage: false), findsOneWidget);
  });

  testWidgets('the semantics stay: subject as header, message header expanded, one custom action', (tester) async {
    final handle = tester.ensureSemantics();
    await _start(tester);
    await _open(tester, 'h1');
    final subject = tester.getSemantics(
      find.descendant(of: _conversation, matching: find.text('Contratto Rossi')).first,
    );
    expect(subject.getSemanticsData().flagsCollection.isHeader, isTrue);
    final header = tester.getSemantics(
      find.descendant(of: find.byType(PostinoThreadMessage).first, matching: find.byType(InkWell)).first,
    );
    expect(header.getSemanticsData().flagsCollection.isExpanded, Tristate.isTrue);
    // On the header, the node screen readers focus, so its details action can be reached.
    expect(header.getSemanticsData().customSemanticsActionIds, hasLength(1));
    handle.dispose();
  });

  testWidgets('banner text is selectable, its button is not (and an empty state has its own area)', (tester) async {
    _mockClipboard(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: PostinoTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              PostinoBanner(
                tone: PostinoBannerTone.danger,
                title: 'Titolo errore',
                message: 'Dettaglio errore',
                actionLabel: 'Riprova',
                onAction: () {},
              ),
              const Expanded(
                child: PostinoEmptyState(title: 'Tutto letto', body: 'Niente da fare'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Dettaglio errore'));
    await tester.pump();
    await _chord(tester, _ctrl, LogicalKeyboardKey.keyA);
    await _chord(tester, _ctrl, LogicalKeyboardKey.keyC);
    expect(_clipboard, contains('Titolo errore'));
    expect(_clipboard, contains('Dettaglio errore'));
    expect(_clipboard, isNot(contains('Riprova')));
    expect(_clipboard, isNot(contains('Tutto letto')));

    await tester.tap(find.text('Niente da fare'));
    await tester.pump();
    await _chord(tester, _ctrl, LogicalKeyboardKey.keyA);
    await _chord(tester, _ctrl, LogicalKeyboardKey.keyC);
    expect(_clipboard, contains('Tutto letto'));
    expect(_clipboard, contains('Niente da fare'));
  });

  testWidgets('the Snackbar of Annulla invio: its state text is selectable, «Annulla» is not', (tester) async {
    _mockClipboard(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: PostinoTheme.light(),
        home: Scaffold(
          body: PostinoSnackbar(
            message: "In attesa d'invio",
            actionLabel: 'Annulla',
            until: DateTime.now().add(PostinoMotion.undoWindow),
            onAction: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text("In attesa d'invio"));
    await tester.pump();
    await _chord(tester, _ctrl, LogicalKeyboardKey.keyA);
    await _chord(tester, _ctrl, LogicalKeyboardKey.keyC);
    expect(_clipboard, contains("In attesa d'invio"));
    expect(_clipboard, isNot(contains('Annulla')));
  });
}
