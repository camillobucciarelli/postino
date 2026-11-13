import 'dart:async';

// Rispondi, Rispondi a tutti and Inoltra (#37): from the bar under the Conversazione, from the menu of a
// message and with r / a / f, a Bozza with the Citazione is saved and opened in the composer; the
// composer keeps the reply headers and the forwarded attachments on every save.

import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/outbox_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _desktop = Size(1600, 900);

late Harness h;
late FakeMailProvider gmail;

DateTime _day(int d) => DateTime.utc(2026, 10, d, 9);

/// Conversazione t: Bruno writes to a1 and Carla, cc Ada (m1, read); Ada answers (m2, read);
/// Bruno again with a PDF (m3, unread, latest).
void _thread(FakeMailProvider p) => p
  ..deliver(
    msg(
      'm1',
      conversationId: 't',
      from: 'bruno@example.com',
      fromName: 'Bruno',
      to: ['a1@example.com', 'carla@example.com'],
      cc: ['ada@example.com'],
      subject: 'Cena',
      snippet: 'Venerdì?',
      date: _day(1),
      isRead: true,
    ),
  )
  ..deliver(
    msg(
      'm2',
      conversationId: 't',
      to: ['bruno@example.com', 'a1@example.com'],
      subject: 'Re: Cena',
      snippet: 'Sì!',
      date: _day(2),
      isRead: true,
    ),
  )
  ..deliver(
    msg(
      'm3',
      conversationId: 't',
      from: 'bruno@example.com',
      to: ['a1@example.com', 'carla@example.com'],
      cc: ['ada@example.com'],
      subject: 'Re: Cena',
      snippet: 'Alle 20',
      date: _day(3),
    ),
  )
  ..bodies['m3'] = const MessageBody('<p>Alle 20</p><p>Porto il vino</p>', BodyKind.html)
  ..attach('m3', 'Contratto.pdf', List.filled(1024, 7))
  ..attach('m3', 'fattura\u202Efdp.exe', List.filled(10, 5));

Future<void> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = _desktop
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  gmail = await h.addAccount('a1');
  _thread(gmail);
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('row-a1-m3')));
  await _settle(tester);
}

/// flutter_quill reads the platform once: macOS, as the app in QA; semantics on, for the labels.
void _onMac(String name, Future<void> Function(WidgetTester) body) => testWidgets(name, (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  final semantics = tester.ensureSemantics();
  try {
    await body(tester);
    // The composer left open: Esc flushes its Bozza now, before the tree and the database go.
    if (find.byType(PostinoComposerLayout).evaluate().isNotEmpty) {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
    }
  } finally {
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  }
});

/// Frames plus the event queue: the database answers between frames.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(pumpEventQueue);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await _settle(tester);
}

/// The Message-ID of the open Bozza, from the URI (the composer is open).
String _openId() {
  final seg = Routefly.currentUri.pathSegments;
  expect(seg[2], 'bozza');
  return seg[3];
}

/// The Bozza as the database keeps it.
Future<OutgoingMessage> _draft(String id) async => (await GetIt.I<OutboxStore>().localDraft('a1', id))!.draft;

/// m1 without its body and the Provider unreachable: the body cannot be downloaded.
Future<void> _forgetBodyOfM1(WidgetTester tester) async {
  final db = GetIt.I<PostinoDatabase>();
  await tester.runAsync(() => (db.delete(db.bodies)..where((t) => t.messageId.equals('m1'))).go());
  gmail.goOffline();
  await _settle(tester);
}

/// The Message-IDs of the Bozze waiting in the database.
Future<List<String>> _pendingIds() async =>
    (await GetIt.I<OutboxStore>().pendingDrafts('a1')).map((d) => d.draft.messageId).toList();

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is PostinoComposerField && w.label == label),
  matching: find.byType(TextField),
);

String _text(WidgetTester tester, String label) => tester.widget<TextField>(_field(label)).controller!.text;

void main() {
  _onMac('Rispondi from the bar: a Bozza to the sender of the last message, '
      'with Re:, In-Reply-To, the Conversazione and the Citazione', (tester) async {
    await _start(tester);
    for (final label in ['Rispondi', 'Rispondi a tutti', 'Inoltra']) {
      expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
    }
    await _tap(tester, find.byKey(const ValueKey('reply')));
    final d = await _draft(_openId());
    expect(d.to, ['bruno@example.com']);
    expect(d.cc, isEmpty);
    expect(d.subject, 'Re: Cena');
    expect(d.inReplyTo, '<m3@example.com>');
    expect(d.references, ['<m3@example.com>']);
    expect(d.conversationId, 't');
    expect(d.body, contains('<blockquote>'));
    expect(d.body, contains('Porto il vino'));
    expect(d.body, contains('ha scritto:'));
    expect(d.attachments, isEmpty);
    expect(_text(tester, 'A'), 'bruno@example.com');
    expect(_text(tester, 'Oggetto'), 'Re: Cena');
    // The Citazione is in the editor, quoted, line by line.
    final doc = tester.widget<QuillEditor>(find.byType(QuillEditor)).controller.document;
    expect(doc.toPlainText(), contains('Porto il vino'));
    expect(doc.toDelta().toJson().where((op) => (op['attributes'] as Map?)?['blockquote'] == true), hasLength(2));
  });

  _onMac('Rispondi a tutti: everyone but the Account itself', (tester) async {
    await _start(tester);
    await _tap(tester, find.byKey(const ValueKey('reply-all')));
    final d = await _draft(_openId());
    expect(d.to, ['bruno@example.com', 'carla@example.com']);
    expect(d.cc, ['ada@example.com']);
    expect(d.inReplyTo, '<m3@example.com>');
    expect(_text(tester, 'Cc'), 'ada@example.com');
  });

  _onMac('Inoltra: no recipients, Fwd:, the original attachments shown read-only', (tester) async {
    await _start(tester);
    await _tap(tester, find.byKey(const ValueKey('forward')));
    final d = await _draft(_openId());
    expect(d.to, isEmpty);
    expect(d.subject, 'Fwd: Cena');
    expect(d.inReplyTo, isNull);
    expect(d.conversationId, isNull);
    expect(d.attachments.map((a) => a.attachment.name), ['Contratto.pdf', 'fattura\u202Efdp.exe']);
    expect(d.attachments.first.sourceMessageId, 'm3');
    expect(d.body, contains('Messaggio inoltrato'));
    expect(find.text('Allegati'), findsOneWidget);
    expect(find.byKey(const ValueKey('draft-attachment-att-Contratto.pdf')), findsOneWidget);
    expect(find.text('Contratto.pdf'), findsOneWidget);
  });

  _onMac('Inoltra: the chip of an attachment name drops bidi controls', (tester) async {
    await _start(tester);
    await _tap(tester, find.byKey(const ValueKey('forward')));
    expect(find.textContaining('\u202E'), findsNothing);
    expect(find.text('fatturafdp.exe'), findsOneWidget);
  });

  _onMac('the menu of an older message replies to that one, its body fetched first', (tester) async {
    await _start(tester);
    await _tap(tester, find.byKey(const ValueKey('message-actions-m1')));
    await _tap(tester, find.byKey(const ValueKey('message-reply-m1')));
    final d = await _draft(_openId());
    expect(d.inReplyTo, '<m1@example.com>');
    expect(d.to, ['Bruno <bruno@example.com>']);
    expect(d.body, contains('Corpo di m1'));
  });

  _onMac('r, a and f act on the last message of the open Conversazione', (tester) async {
    await _start(tester);
    for (final (key, subject, to) in [
      (LogicalKeyboardKey.keyR, 'Re: Cena', ['bruno@example.com']),
      (LogicalKeyboardKey.keyA, 'Re: Cena', ['bruno@example.com', 'carla@example.com']),
      (LogicalKeyboardKey.keyF, 'Fwd: Cena', <String>[]),
    ]) {
      // A focus outside a text field: the first Tab stop.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(key);
      await _settle(tester);
      final d = await _draft(_openId());
      expect(d.subject, subject, reason: '$key');
      expect(d.to, to, reason: '$key');
      // Back to the list, then the Conversazione again.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      await _tap(tester, find.byKey(const ValueKey('row-a1-m3')));
    }
  });

  _onMac('r typed in the composer editor is a letter, not a reply', (tester) async {
    await _start(tester);
    await _tap(tester, find.byKey(const ValueKey('reply')));
    final id = _openId();
    await tester.tap(find.byType(QuillEditor));
    await tester.pump();
    // r has no reply to start under the open composer, so c (a new Bozza) shows the guard: both are letters.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await _settle(tester);
    // Nothing replied: still the same open Bozza, and no second one.
    expect(_openId(), id);
    expect(await _pendingIds(), [id]);
  });

  _onMac('closing the Conversazione while the body for Rispondi downloads '
      'makes no Bozza and opens no composer', (tester) async {
    await _start(tester);
    gmail.holdBody = Completer<void>();
    await _tap(tester, find.byKey(const ValueKey('message-actions-m1')));
    await _tap(tester, find.byKey(const ValueKey('message-reply-m1')));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byKey(const ValueKey('message-actions-m1')), findsNothing);
    gmail.holdBody!.complete();
    await _settle(tester);
    expect(await _pendingIds(), isEmpty);
    expect(find.byType(PostinoComposerLayout), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _onMac('Rispondi when the body cannot be downloaded quotes the snippet', (tester) async {
    await _start(tester);
    await _forgetBodyOfM1(tester);
    await _tap(tester, find.byKey(const ValueKey('message-actions-m1')));
    await _tap(tester, find.byKey(const ValueKey('message-reply-m1')));
    final d = await _draft(_openId());
    expect(d.inReplyTo, '<m1@example.com>');
    expect(d.body, contains('Venerdì?'));
  });

  _onMac('Inoltra when the body cannot be downloaded makes no Bozza and says so', (tester) async {
    await _start(tester);
    await _forgetBodyOfM1(tester);
    await _tap(tester, find.byKey(const ValueKey('message-actions-m1')));
    await _tap(tester, find.byKey(const ValueKey('message-forward-m1')));
    expect(await _pendingIds(), isEmpty);
    expect(find.byType(PostinoComposerLayout), findsNothing);
    expect(find.text('Impossibile inoltrare: messaggio non scaricato'), findsOneWidget);
  });

  _onMac('r twice before the first save ends makes one Bozza', (tester) async {
    await _start(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await _settle(tester);
    expect(await _pendingIds(), hasLength(1));
  });

  _onMac('keyboard: Tab reaches Rispondi, Enter replies', (tester) async {
    await _start(tester);
    for (var i = 0; i < 40; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focused = primaryFocus?.context;
      if (focused != null &&
          find
              .ancestor(of: find.byElementPredicate((e) => e == focused), matching: find.byKey(const ValueKey('reply')))
              .evaluate()
              .isNotEmpty) {
        break;
      }
      if (i == 39) fail('Tab never reached Rispondi');
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect((await _draft(_openId())).inReplyTo, '<m3@example.com>');
  });

  _onMac('the composer keeps In-Reply-To, References, the Conversazione and '
      'the attachments on every save', (tester) async {
    await _start(tester);
    await _tap(tester, find.byKey(const ValueKey('forward')));
    final fwd = _openId();
    await tester.enterText(_field('A'), 'dee@example.com');
    await _settle(tester);
    h.clock.advance(const Duration(seconds: 5));
    await _settle(tester);
    expect(gmail.draftCalls, [(fwd, true)]);
    expect(gmail.drafts[fwd]!.attachments.map((a) => a.attachment.name), ['Contratto.pdf', 'fattura\u202Efdp.exe']);
    expect((await _draft(fwd)).attachments, hasLength(2));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    await _tap(tester, find.byKey(const ValueKey('row-a1-m3')));
    await _tap(tester, find.byKey(const ValueKey('reply')));
    final re = _openId();
    await tester.enterText(_field('Oggetto'), 'Re: Cena di venerdì');
    await _settle(tester);
    final d = await _draft(re);
    expect(d.subject, 'Re: Cena di venerdì');
    expect(d.inReplyTo, '<m3@example.com>');
    expect(d.references, ['<m3@example.com>']);
    expect(d.conversationId, 't');
  });
}
