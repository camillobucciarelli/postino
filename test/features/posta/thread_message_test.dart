// The complete message header and the folded quote and signature in a Conversazione (#47, ThreadView).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

DateTime _day(int d) => DateTime.utc(2026, 10, d, 9);

String _fixture(String name) =>
    File('test/fixtures/quote/$name').readAsStringSync();

Future<void> _start(
  WidgetTester tester,
  void Function(FakeMailProvider p) mailbox,
) async {
  tester.view
    ..physicalSize = const Size(800, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  mailbox(await h.addAccount('a1'));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  Routefly.navigate(routePaths.posta.path);
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String latest) async {
  await tester.tap(find.byKey(ValueKey('row-a1-$latest')));
  await tester.pumpAndSettle();
}

Finder _in(String id, Finder f) =>
    find.descendant(of: find.byKey(ValueKey('message-$id')), matching: f);

Finder _text(String s) => find.textContaining(s, findRichText: true);

void main() {
  group('header', () {
    void mailbox(FakeMailProvider p) {
      p
        ..bodies['h1'] = const MessageBody('Ciao Giulia', BodyKind.testo)
        ..deliver(
          msg(
            'h1',
            conversationId: 'h',
            from: 'ada@okafor-legal.it',
            fromName: 'Ada Okafor',
            to: const ['Giulia Ferri <a1@example.com>'],
            cc: const ['Marco Lenti <marco@example.com>', 'luca@example.com'],
            subject: 'Contratto Rossi',
            labelIds: const [inboxLabelId, 'IMPORTANT'],
            date: _day(1),
          ),
        )
        ..bodies['n1'] = const MessageBody('Offerte', BodyKind.testo)
        ..deliver(
          msg(
            'n1',
            conversationId: 'n',
            from: 'news@shop.example',
            subject: 'Offerte',
            date: _day(2),
          ),
        );
    }

    testWidgets(
      'name and address, «a me, cc …», the details with Cc, Importante',
      (tester) async {
        await _start(tester, mailbox);
        // The list shows the name too.
        expect(_text('Ada Okafor'), findsOneWidget);
        await _open(tester, 'h1');

        expect(
          _in('h1', _text('Ada Okafor ada@okafor-legal.it')),
          findsOneWidget,
        );
        expect(
          _in('h1', _text('a me, cc Marco Lenti, luca@example.com')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('important')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('Importante')), findsOneWidget);

        await tester.tap(_in('h1', _text('a me, cc')));
        await tester.pumpAndSettle();
        expect(_text('Ada Okafor <ada@okafor-legal.it>'), findsOneWidget);
        expect(_text('Giulia Ferri <a1@example.com>'), findsOneWidget);
        expect(find.text('Cc'), findsOneWidget);
        expect(
          _text('Marco Lenti <marco@example.com>, luca@example.com'),
          findsOneWidget,
        );
      },
    );

    testWidgets('without a name only the address; without IMPORTANT no mark', (
      tester,
    ) async {
      await _start(tester, mailbox);
      await _open(tester, 'n1');
      final sender = tester.widget<Text>(
        _in(
          'n1',
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.textSpan?.toPlainText() ?? '').startsWith('news@'),
          ),
        ),
      );
      expect(sender.textSpan!.toPlainText(), 'news@shop.example');
      expect(find.byKey(const ValueKey('important')), findsNothing);
      expect(_in('n1', _text('a me')), findsOneWidget);
      expect(_in('n1', _text('cc')), findsNothing);
    });
  });

  group('quote and signature', () {
    void mailbox(FakeMailProvider p) {
      // Ada signs twice: the second time her signature folds with the quote.
      p
        ..bodies['q1'] = const MessageBody(
          'Ti va una cena venerdì?\n-- \nAda Okafor\nOkafor Legal',
          BodyKind.testo,
        )
        ..deliver(
          msg('q1', conversationId: 'q', subject: 'Cena', date: _day(1)),
        )
        ..bodies['q2'] = MessageBody(
          _fixture('gmail_reply.html'),
          BodyKind.html,
        )
        ..deliver(
          msg('q2', conversationId: 'q', subject: 'Cena', date: _day(2)),
        )
        ..bodies['q3'] = MessageBody(
          _fixture('plain_reply.txt'),
          BodyKind.testo,
        )
        ..deliver(
          msg('q3', conversationId: 'q', subject: 'Cena', date: _day(3)),
        );
    }

    testWidgets(
      'the quote hides behind «…» («Mostra testo citato»): a tap shows it, another hides it',
      (tester) async {
        await _start(tester, mailbox);
        await _open(tester, 'q3');

        final toggle = _in('q2', find.byKey(const ValueKey('quote-toggle')));
        expect(_in('q2', _text('Ciao Giulia')), findsOneWidget);
        expect(_in('q2', _text('modifiche del cliente')), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('message-q2')),
            matching: find.bySemanticsLabel('Mostra testo citato'),
          ),
          findsOneWidget,
        );

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(_in('q2', _text('modifiche del cliente')), findsOneWidget);
        // Per message: the other one stays folded.
        expect(_in('q3', _text('Avevamo detto giovedì')), findsNothing);

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(_in('q2', _text('modifiche del cliente')), findsNothing);
      },
    );

    testWidgets(
      'the signature shows in body-quote ink-muted; repeated, it folds with the quote',
      (tester) async {
        await _start(tester, mailbox);
        await _open(tester, 'q3');

        final first = tester.widget<Text>(
          _in('q1', find.text('-- \nAda Okafor\nOkafor Legal')),
        );
        expect(first.data, '-- \nAda Okafor\nOkafor Legal');
        final muted = tester
            .element(_in('q1', find.text('-- \nAda Okafor\nOkafor Legal')))
            .pc
            .inkMuted;
        expect(first.style?.fontSize, PostinoText.bodyQuote.fontSize);
        expect(first.style?.height, PostinoText.bodyQuote.height);
        expect(first.style?.color, muted);

        // q3 signs the same: folded until «…».
        expect(
          _in('q3', find.text('-- \nAda Okafor\nOkafor Legal')),
          findsNothing,
        );
        await tester.tap(_in('q3', find.byKey(const ValueKey('quote-toggle'))));
        await tester.pumpAndSettle();
        expect(_in('q3', _text('Ada Okafor\nOkafor Legal')), findsOneWidget);
        expect(_in('q3', _text('Avevamo detto giovedì')), findsOneWidget);

        // The HTML signature is a quiet card.
        final cards = tester.widgetList<PostinoHtmlCard>(
          _in('q2', find.byType(PostinoHtmlCard)),
        );
        expect([for (final c in cards) c.quiet], [false, true]);
      },
    );

    testWidgets(
      'the «…» toggle is focusable: Enter and Space open and close it',
      (tester) async {
        await _start(tester, mailbox);
        await _open(tester, 'q3');
        final toggle = _in('q2', find.byKey(const ValueKey('quote-toggle')));
        expect(_in('q2', _text('modifiche del cliente')), findsNothing);

        Future<void> press(LogicalKeyboardKey k) async {
          await tester.sendKeyEvent(k);
          await tester.pumpAndSettle();
        }

        // Tab until the toggle has focus.
        bool focused() =>
            find
                .descendant(
                  of: toggle,
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is Focus && (w.focusNode?.hasPrimaryFocus ?? false) ||
                        false,
                  ),
                )
                .evaluate()
                .isNotEmpty ||
            FocusManager.instance.primaryFocus?.context != null &&
                find
                    .ancestor(
                      of: find.byElementPredicate(
                        (e) => e == FocusManager.instance.primaryFocus!.context,
                      ),
                      matching: toggle,
                    )
                    .evaluate()
                    .isNotEmpty;
        for (var i = 0; i < 60 && !focused(); i++) {
          await press(LogicalKeyboardKey.tab);
        }
        expect(focused(), isTrue);
        await press(LogicalKeyboardKey.enter);
        expect(_in('q2', _text('modifiche del cliente')), findsOneWidget);
        await press(LogicalKeyboardKey.space);
        expect(_in('q2', _text('modifiche del cliente')), findsNothing);
      },
    );
  });
}
