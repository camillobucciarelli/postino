// Opening and reading a Conversazione (#33): beside the list from 900, a full page below,
// the whole thread from the database and the fake Provider, bodies on demand, read state.

import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart' show Material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/features/posta/presentation/message_list.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import '../../support/html_fallback_engine.dart';
import '../../support/ui.dart';

const _desktop = Size(1600, 900);
const _phone = Size(390, 844);

DateTime _day(int d) => DateTime.utc(2026, 10, d, 9);

late Harness h;
late FakeMailProvider gmail;

/// Starts the app at [size] with Account a1 and whatever [mailbox] delivers to its Provider.
Future<void> _start(WidgetTester tester, Size size, void Function(FakeMailProvider p) mailbox) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  gmail = await h.addAccount('a1');
  mailbox(gmail);
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  // Routefly keeps the last navigation in statics.
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

/// Conversazione t: Bruno writes (read), Ada answers (read), Bruno again (unread, latest).
void _thread(FakeMailProvider p) => p
  ..deliver(
    msg(
      'm1',
      conversationId: 't',
      from: 'bruno@example.com',
      subject: 'Cena',
      snippet: 'Venerdì?',
      date: _day(1),
      isRead: true,
    ),
  )
  ..deliver(msg('m2', conversationId: 't', subject: 'Re: Cena', snippet: 'Sì!', date: _day(2), isRead: true))
  ..deliver(
    msg('m3', conversationId: 't', from: 'bruno@example.com', subject: 'Re: Cena', snippet: 'Alle 20', date: _day(3)),
  )
  ..deliver(msg('o1', conversationId: 'o', subject: 'Altro', date: _day(4), isRead: true));

Finder _row(String latest) => find.byKey(ValueKey('row-a1-$latest'));
Finder _message(String id) => find.byKey(ValueKey('message-$id'));

PostinoMessageTile _tile(WidgetTester tester, String latest) => tester.widget<PostinoMessageTile>(_row(latest));

bool _expanded(WidgetTester tester, String id) => tester.widget<PostinoThreadMessage>(_message(id)).expanded;

/// What reached the Provider's setRead, comparable.
List<(String, bool)> get _readCalls => [for (final (ids, read) in gmail.readCalls) (ids.join(','), read)];

Future<void> _open(WidgetTester tester, String latest) async {
  await tester.tap(_row(latest));
  await tester.pumpAndSettle();
}

/// Every Text sits under a Material (else Flutter draws the debug yellow underline).
void _expectAllTextInMaterial(WidgetTester tester) {
  final texts = find.byType(Text).evaluate().toList();
  expect(texts, isNotEmpty);
  for (final e in texts) {
    expect(
      find.ancestor(of: find.byWidget(e.widget), matching: find.byType(Material)),
      findsWidgets,
      reason: 'Text "${(e.widget as Text).data}" has no Material ancestor',
    );
  }
}

void main() {
  // Looks for the body's text and links as widgets.
  setUp(useHtmlFallbackEngine);
  for (final size in [_desktop, _phone]) {
    testWidgets('at ${size.width.toInt()}×${size.height.toInt()} all text of the Conversazione is under a Material', (
      tester,
    ) async {
      await _start(tester, size, _thread);
      _expectAllTextInMaterial(tester);
      await _open(tester, 'm3');
      expect(find.byType(ConversationView), findsOneWidget);
      _expectAllTextInMaterial(tester);
    });
  }

  testWidgets('the list has one row per Conversazione, with its count and unread state', (tester) async {
    await _start(tester, _phone, _thread);

    expect(_row('m1'), findsNothing);
    expect(_row('m2'), findsNothing);
    final t = _tile(tester, 'm3');
    expect((t.count, t.unread, t.subject), (3, true, 'Re: Cena'));
    expect(find.descendant(of: _row('m3'), matching: find.byKey(const ValueKey('count'))), findsOneWidget);
    final o = _tile(tester, 'o1');
    expect((o.count, o.unread), (1, false));
    expect(find.descendant(of: _row('o1'), matching: find.byKey(const ValueKey('count'))), findsNothing);
  });

  testWidgets(
    'at 1600×900 a tap opens the Conversazione beside the list, which stays mounted and highlights the row; Esc closes it',
    (tester) async {
      await _start(tester, _desktop, _thread);
      final list = tester.state(find.byType(MessageList));
      expect(find.text('Seleziona una Conversazione'), findsOneWidget);
      expect(_tile(tester, 'm3').selected, isFalse);

      await _open(tester, 'm3');
      expect(find.byType(ConversationView), findsOneWidget);
      expect(tester.state(find.byType(MessageList)), same(list));
      expect(_tile(tester, 'm3').selected, isTrue);
      expect(_tile(tester, 'o1').selected, isFalse);
      // Beside the list, which keeps its place.
      expect(
        tester.getTopLeft(find.byType(ConversationView)).dx,
        greaterThan(PostinoSize.sidebarWidth + PostinoSize.listWidth),
      );
      expect(find.text('Seleziona una Conversazione'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ConversationView), findsNothing);
      expect(find.text('Seleziona una Conversazione'), findsOneWidget);
      expect(tester.state(find.byType(MessageList)), same(list));
      expect(_tile(tester, 'm3').selected, isFalse);
    },
  );

  testWidgets(
    'crossing 900 with a Conversazione open keeps its State, scroll and expansion choices, and the list State',
    (tester) async {
      // Twelve unread messages: all expanded when they show up, long enough to scroll.
      await _start(tester, _desktop, (p) {
        for (var i = 0; i < 12; i++) {
          p.deliver(msg('l$i', conversationId: 'l', date: DateTime.utc(2026, 10, 5, i)));
        }
      });
      // Offstage under the full page on the phone, still mounted.
      State list() => tester.state(find.byType(MessageList, skipOffstage: false));
      final l = list();
      await _open(tester, 'l11');
      State conversation() => tester.state(find.byType(ConversationView));
      final c = conversation();
      ScrollPosition scroll() => tester
          .state<ScrollableState>(
            find.descendant(of: find.byType(PostinoThreadView), matching: find.byType(Scrollable)).first,
          )
          .position;
      // The user collapses the latest one (a tap on its header) and scrolls down.
      await tester.tap(find.descendant(of: _message('l11'), matching: find.byType(PostinoAvatar)));
      await tester.pumpAndSettle();
      expect(_expanded(tester, 'l11'), isFalse);
      expect(scroll().maxScrollExtent, greaterThan(100));
      scroll().jumpTo(100);
      await tester.pump();

      for (final size in [_phone, _desktop, _phone]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(conversation(), same(c), reason: 'at $size');
        expect(list(), same(l), reason: 'at $size');
        expect(scroll().pixels, 100, reason: 'at $size');
        // Its choice stays; the others, read by now, stay expanded.
        expect(_expanded(tester, 'l11'), isFalse, reason: 'at $size');
        expect(_expanded(tester, 'l10'), isTrue, reason: 'at $size');
      }
    },
  );

  testWidgets('at 1600×900 there is no Indietro; Esc closes the Conversazione', (tester) async {
    await _start(tester, _desktop, _thread);
    await _open(tester, 'm3');
    expect(icon(PostinoIcons.arrowLeft), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsNothing);
    expect(find.text('Seleziona una Conversazione'), findsOneWidget);
  });

  testWidgets('at 390×844 a tap opens a full page; Indietro comes back to the list with its scroll unchanged', (
    tester,
  ) async {
    await _start(tester, _phone, (p) {
      for (var i = 0; i < 30; i++) {
        p.deliver(
          msg(
            'n$i',
            subject: 'Messaggio $i',
            date: _day(1).add(Duration(hours: i)),
            // Read: a long list without sections (#366).
            isRead: true,
          ),
        );
      }
    });
    final list = tester.state(find.byType(MessageList));
    ScrollPosition position() => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(MessageList, skipOffstage: false),
            matching: find.byType(Scrollable, skipOffstage: false),
          ),
        )
        .position;
    await tester.drag(find.byType(MessageList), const Offset(0, -900));
    await tester.pumpAndSettle();
    final scrolled = position().pixels;
    expect(scrolled, greaterThan(0));

    final row = find.byType(PostinoMessageTile).first;
    await tester.tap(row);
    await tester.pumpAndSettle();
    final page = find.byType(ConversationView);
    expect(tester.getSize(page), _phone);
    // Covered, not gone.
    expect(find.byType(MessageList), findsNothing);
    expect(find.byType(MessageList, skipOffstage: false), findsOneWidget);
    expect(icon(PostinoIcons.arrowLeft), findsOneWidget);

    await tester.tap(icon(PostinoIcons.arrowLeft));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationView), findsNothing);
    expect(tester.state(find.byType(MessageList)), same(list));
    expect(position().pixels, scrolled);
  });

  testWidgets('at 390×844 the page slides in with a fade (shared axis X)', (tester) async {
    await _start(tester, _phone, _thread);
    await tester.tap(_row('m3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final page = find.byType(ConversationView);
    expect(page, findsOneWidget);
    final opacity = tester.widget<Opacity>(find.ancestor(of: page, matching: find.byType(Opacity)).first).opacity;
    expect(opacity, inExclusiveRange(0, 1));
    expect(tester.getTopLeft(page).dx, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(page).dx, 0);
  });

  testWidgets('with reduced motion the page opens at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _start(tester, _phone, _thread);
    await tester.tap(_row('m3'));
    await tester.pump();
    await tester.pump();
    expect(tester.getTopLeft(find.byType(ConversationView)).dx, 0);
    expect(find.byType(MessageList), findsNothing);
  });

  testWidgets('switching from one Conversazione to another never shows the wrong content', (tester) async {
    await _start(tester, _desktop, _thread);
    await _open(tester, 'm3');
    expect(find.text('Corpo di m3'), findsOneWidget);

    await tester.tap(_row('o1'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      for (final e in find.byType(ConversationView).evaluate()) {
        final view = e.widget as ConversationView;
        final other = view.conversationId == 't' ? 'Corpo di o1' : 'Corpo di m3';
        final inView = find.descendant(of: find.byWidget(view), matching: find.text(other));
        expect(inView, findsNothing, reason: 'frame $i, ${view.conversationId}');
      }
    }
    await tester.pumpAndSettle();
    final view = tester.widget<ConversationView>(find.byType(ConversationView));
    expect(view.conversationId, 'o');
    expect(find.text('Corpo di o1'), findsOneWidget);
    expect(find.text('Corpo di m3'), findsNothing);
    expect(_tile(tester, 'o1').selected, isTrue);
    expect(_tile(tester, 'm3').selected, isFalse);
  });

  testWidgets('messages newest first; only the latest and the unread expanded; a tap expands a collapsed one', (
    tester,
  ) async {
    await _start(tester, _phone, (p) {
      _thread(p);
      // An older unread one in the middle stays expanded too.
      p.deliver(
        copyOf(msg('m2', conversationId: 't', subject: 'Re: Cena', snippet: 'Sì!', date: _day(2)), isRead: false),
      );
    });
    await _open(tester, 'm3');

    final ys = <double>[
      for (final id in ['m1', 'm2', 'm3']) tester.getTopLeft(_message(id)).dy,
    ];
    expect(ys, orderedEquals(<double>[...ys]..sort((a, b) => b.compareTo(a))), reason: 'newest first');
    expect(_expanded(tester, 'm1'), isFalse);
    expect(_expanded(tester, 'm2'), isTrue, reason: 'unread');
    expect(_expanded(tester, 'm3'), isTrue, reason: 'latest');
    expect(find.text('Corpo di m3'), findsOneWidget);
    // Collapsed: sender and preview, no body.
    expect(find.descendant(of: _message('m1'), matching: find.text('Venerdì?')), findsOneWidget);
    expect(find.text('Corpo di m1'), findsNothing);

    await tester.tap(find.text('Venerdì?'));
    await tester.pumpAndSettle();
    expect(_expanded(tester, 'm1'), isTrue);
    expect(find.text('Corpo di m1'), findsOneWidget);
    // Opening marked them read, yet they stay expanded.
    expect(_expanded(tester, 'm2'), isTrue);
  });

  testWidgets('a reply in Inviati missing from the database is fetched from the Provider and shown', (tester) async {
    await _start(tester, _phone, (p) {
      _thread(p);
      p.deliverOutsideWindow(
        msg(
          's0',
          conversationId: 't',
          from: 'a1@example.com',
          subject: 'Cena',
          snippet: 'Organizziamo?',
          date: DateTime.utc(2026, 6),
          isRead: true,
          labelIds: const ['SENT'],
        ),
      );
    });
    expect(_tile(tester, 'm3').count, 3);
    await _open(tester, 'm3');

    expect(_message('s0'), findsOneWidget);
    expect(
      tester.getTopLeft(_message('s0')).dy,
      greaterThan(tester.getTopLeft(_message('m1')).dy),
      reason: 'the oldest, at the bottom',
    );
    // It stays in the database: the list counts it now.
    await tester.tap(icon(PostinoIcons.arrowLeft));
    await tester.pumpAndSettle();
    expect(_tile(tester, 'm3').count, 4);
  });

  testWidgets(
    'a deep link to a Conversazione not in the database shows its latest message, read, expanded with its body',
    (tester) async {
      await _start(tester, _phone, (p) {
        for (final (id, d) in [('x1', 1), ('x2', 2)]) {
          p.deliverOutsideWindow(msg(id, conversationId: 'x', date: _day(d), isRead: true));
        }
      });
      unawaited(
        Routefly.navigate(
          routePaths.posta.$accountId.conversazione.$conversationId.changes({'accountId': 'a1', 'conversationId': 'x'}),
        ),
      );
      await tester.pumpAndSettle();

      expect(_expanded(tester, 'x1'), isFalse);
      expect(_expanded(tester, 'x2'), isTrue, reason: 'latest');
      expect(find.text('Corpo di x2'), findsOneWidget);
    },
  );

  testWidgets(
    'a newer read reply fetched from the Provider becomes the latest, expanded; a message the user collapsed stays so',
    (tester) async {
      await _start(tester, _phone, (p) {
        _thread(p);
        p.deliverOutsideWindow(
          msg(
            's4',
            conversationId: 't',
            from: 'a1@example.com',
            subject: 'Re: Cena',
            snippet: 'Perfetto',
            date: _day(5),
            isRead: true,
            labelIds: const ['SENT'],
          ),
        );
      });
      await _open(tester, 'm3');

      expect(_expanded(tester, 's4'), isTrue, reason: 'the latest now');
      expect(find.text('Corpo di s4'), findsOneWidget);
      expect(_expanded(tester, 'm3'), isTrue, reason: 'was unread');

      // The avatar collapses; the text is for selecting.
      await tester.tap(find.descendant(of: _message('m3'), matching: find.byType(PostinoAvatar)).first);
      await tester.pumpAndSettle();
      expect(_expanded(tester, 'm3'), isFalse);
      gmail.deliver(msg('m3', conversationId: 't', date: _day(3), isStarred: true));
      await tester.pumpAndSettle();
      expect(_expanded(tester, 'm3'), isFalse);
    },
  );

  testWidgets('opened offline, the messages missing from the database are fetched when the network returns', (
    tester,
  ) async {
    await _start(tester, _phone, (p) {
      _thread(p);
      p.deliverOutsideWindow(
        msg(
          's0',
          conversationId: 't',
          subject: 'Cena',
          date: DateTime.utc(2026, 6),
          isRead: true,
          labelIds: const ['SENT'],
        ),
      );
    });
    gmail.goOffline();
    h.connectivity.online = false;
    await _open(tester, 'm3');
    expect(_message('s0'), findsNothing);

    gmail.goOnline();
    h.connectivity.online = true;
    await tester.pumpAndSettle();
    expect(_message('s0'), findsOneWidget);
  });

  group('a body missing from the database', () {
    /// Conversazione t: an inbox message (body synced) and a later one only in an Etichetta (no body).
    void mailbox(FakeMailProvider p) => p
      ..bodyKind = BodyKind.html
      ..deliver(msg('i1', conversationId: 't', date: _day(1), isRead: true))
      ..deliver(msg('e2', conversationId: 't', date: _day(2), labelIds: const ['Label_12']));

    Future<List<BodyRow>> bodies() => getIt<PostinoDatabase>().select(getIt<PostinoDatabase>().bodies).get();

    testWidgets('is downloaded from the Provider and saved with its kind', (tester) async {
      await _start(tester, _phone, mailbox);
      expect((await bodies()).map((b) => b.messageId), ['i1']);

      await _open(tester, 'e2');
      expect(find.text('Corpo di e2', findRichText: true), findsOneWidget);
      final e2 = (await bodies()).singleWhere((b) => b.messageId == 'e2');
      expect((e2.body, e2.kind), ('Corpo di e2', BodyKind.html));
    });

    testWidgets('offline says so with Riprova, which works once back online', (tester) async {
      await _start(tester, _phone, mailbox);
      gmail.goOffline();
      await _open(tester, 'e2');
      expect(find.text('Corpo non disponibile offline'), findsOneWidget);
      expect(find.text('Riprova'), findsOneWidget);

      gmail.goOnline();
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(find.text('Corpo di e2', findRichText: true), findsOneWidget);
      expect(find.text('Corpo non disponibile offline'), findsNothing);
    });

    for (final reduced in [false, true]) {
      testWidgets('Riprova: the note fades into the next one${reduced ? ', at once with reduced motion' : ''} (#283)', (
        tester,
      ) async {
        if (reduced) {
          tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
            disableAnimations: true,
          );
          addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        }
        final handle = tester.ensureSemantics();
        await _start(tester, _phone, mailbox);
        gmail.goOffline();
        await _open(tester, 'e2');
        final note = find.text('Corpo non disponibile offline');
        gmail.goOnline();
        await tester.tap(find.text('Riprova'));
        await tester.pump();
        await tester.pump(PostinoMotion.state ~/ 2);
        if (reduced) {
          expect(note, findsNothing);
        } else {
          final fade = tester.widget<FadeTransition>(
            find.ancestor(of: note, matching: find.byType(FadeTransition)).first,
          );
          expect(fade.opacity.value, inExclusiveRange(0, 1), reason: 'half way it fades out');
          expect(find.semantics.byLabel('Corpo non disponibile offline'), findsNothing, reason: 'not read twice');
          expect(Focus.of(tester.element(find.text('Riprova'))).canRequestFocus, isFalse);
        }
        await tester.pumpAndSettle();
        expect(note, findsNothing);
        handle.dispose();
      });
    }

    testWidgets('offline, it retries by itself when the network returns', (tester) async {
      await _start(tester, _phone, mailbox);
      gmail.goOffline();
      h.connectivity.online = false;
      await _open(tester, 'e2');
      expect(find.text('Corpo non disponibile offline'), findsOneWidget);

      gmail.goOnline();
      h.connectivity.online = true;
      await tester.pumpAndSettle();
      expect(find.text('Corpo di e2', findRichText: true), findsOneWidget);
    });
  });

  group('opening a Conversazione marks it read', () {
    Future<List<IntentRow>> queue() => getIt<PostinoDatabase>().select(getIt<PostinoDatabase>().intents).get();

    testWidgets('here at once and on the Provider', (tester) async {
      await _start(tester, _desktop, _thread);
      await _open(tester, 'm3');

      expect(_tile(tester, 'm3').unread, isFalse);
      expect(_readCalls, [('m3', true)]);
      expect(await queue(), isEmpty);
    });

    testWidgets('offline: here at once, queued, sent when back online', (tester) async {
      await _start(tester, _desktop, _thread);
      gmail.goOffline();
      h.connectivity.online = false;
      await _open(tester, 'm3');

      expect(_tile(tester, 'm3').unread, isFalse);
      expect(_readCalls, isEmpty);
      expect([for (final i in await queue()) (i.messageId, i.attribute, i.wanted)], [('m3', 'read', 'true')]);

      gmail.goOnline();
      h.connectivity.online = true;
      await tester.pumpAndSettle();
      expect(_readCalls, [('m3', true)]);
      expect(await queue(), isEmpty);
      expect(_tile(tester, 'm3').unread, isFalse);
    });
  });

  group('an unread message shown in the open Conversazione is marked read', () {
    void other(FakeMailProvider p) => p.deliver(msg('u1', conversationId: 'u', subject: 'Nuova', date: _day(6)));

    for (final size in [_desktop, _phone]) {
      testWidgets('at ${size.width.toInt()}: moving from one Conversazione to another', (tester) async {
        await _start(tester, size, (p) {
          _thread(p);
          other(p);
        });
        if (size == _phone) {
          await _open(tester, 'm3');
          unawaited(
            Routefly.navigate(
              routePaths.posta.$accountId.conversazione.$conversationId.changes({
                'accountId': 'a1',
                'conversationId': 'u',
              }),
            ),
          );
          await tester.pumpAndSettle();
        } else {
          await _open(tester, 'm3');
          await _open(tester, 'u1');
        }
        expect(_readCalls, containsAll([('m3', true), ('u1', true)]));
        if (size == _desktop) expect(_tile(tester, 'u1').unread, isFalse);
      });
    }

    testWidgets('a new message arriving while it is open', (tester) async {
      await _start(tester, _desktop, _thread);
      await _open(tester, 'm3');
      gmail.deliver(msg('m4', conversationId: 't', date: _day(7)));
      await tester.pumpAndSettle();

      expect(_expanded(tester, 'm4'), isTrue);
      expect(_readCalls, contains(('m4', true)));
      expect(_tile(tester, 'm4').unread, isFalse);
    });
  });
}
