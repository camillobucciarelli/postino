// Composition and Bozze (#35): the Bozza reaches the fake Provider after the 5 s debounce and at once on
// closing, a Bozza of another client is resumed with its formats, one deleted elsewhere drops the local
// edit in silence, offline it waits; the entry points, the semantics and the single pane under 900 px.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';
import '../../support/ui.dart';

const _desktop = Size(1600, 900);
const _phone = Size(390, 844);
const _id = 'a1';

late Harness h;
late FakeMailProvider gmail;

Future<void> _start(WidgetTester tester, {Size size = _desktop}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h = await Harness.create();
  gmail = await h.addAccount(_id);
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  Routefly.navigate(routePaths.posta.path);
  await tester.pumpAndSettle();
}

/// flutter_quill reads the platform once: macOS, as the app in QA; semantics on, for the labels.
void _onMac(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final semantics = tester.ensureSemantics();
      try {
        await body(tester);
      } finally {
        semantics.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });

/// The text field of the composer header line [label].
Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is PostinoComposerField && w.label == label,
  ),
  matching: find.byType(TextField),
);

Future<void> _typeInEditor(WidgetTester tester, String text) async {
  await tester.tap(find.byType(QuillEditor));
  await tester.pump();
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: '$text\n',
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
  await tester.pump();
}

/// Opens a new composition from the FAB and fills A, Oggetto and the body.
Future<void> _write(WidgetTester tester) async {
  await tester.tap(find.text('Scrivi'));
  await tester.pumpAndSettle();
  await tester.enterText(_field('A'), 'ada@example.com');
  await tester.enterText(_field('Cc'), 'Bo <bo@example.com>, cy@example.com');
  await tester.enterText(_field('Ccn'), 'dee@example.com');
  await tester.enterText(_field('Oggetto'), 'Saluti');
  await _typeInEditor(tester, 'Ciao Ada');
  await tester.pumpAndSettle();
}

/// The Message-ID of the open Bozza, from the URI.
String _openId() => Routefly.currentUri.pathSegments[3];

/// Frames plus the event queue: the database answers between frames, with nothing scheduled meanwhile.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(pumpEventQueue);
  await tester.pumpAndSettle();
}

Future<void> _after5s(WidgetTester tester) async {
  await _settle(tester);
  h.clock.advance(const Duration(seconds: 5));
  await _settle(tester);
}

void main() {
  _onMac(
    'a Bozza reaches the Provider after 5 s and keeps its Message-ID on the next edit',
    (tester) async {
      await _start(tester);
      await _write(tester);
      final id = _openId();
      expect(id, matches(RegExp(r'^<.+@example\.com>$')));
      expect(gmail.draftCalls, isEmpty);

      await _after5s(tester);
      expect(gmail.draftCalls, [(id, true)]);
      final d = gmail.drafts[id]!;
      expect(d.from, '$_id@example.com');
      expect(d.to, ['ada@example.com']);
      expect(d.cc, ['Bo <bo@example.com>', 'cy@example.com']);
      expect(d.bcc, ['dee@example.com']);
      expect(d.subject, 'Saluti');
      expect(d.body, contains('Ciao Ada'));

      await tester.enterText(_field('Oggetto'), 'Saluti e baci');
      await _after5s(tester);
      expect(gmail.draftCalls, [(id, true), (id, false)]);
      expect(gmail.drafts[id]!.subject, 'Saluti e baci');
    },
  );

  _onMac('a Bozza emptied after its first save is saved empty', (tester) async {
    await _start(tester);
    await _write(tester);
    final id = _openId();
    await _after5s(tester);
    for (final label in ['A', 'Cc', 'Ccn', 'Oggetto']) {
      await tester.enterText(_field(label), '');
    }
    // Last, so that only the body was left: the save that empties the Bozza for good.
    tester.widget<QuillEditor>(find.byType(QuillEditor)).controller.clear();
    await _after5s(tester);
    final d = gmail.drafts[id]!;
    expect([...d.to, ...d.cc, ...d.bcc, d.subject], ['']);
    expect(d.body, isNot(contains('Ciao Ada')));
  });

  _onMac('the Bozza leaves from the Account chosen in Da', (tester) async {
    await _start(tester);
    final other = await h.addAccount('a2');
    await _settle(tester);
    await tester.tap(find.text('Scrivi'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Da: a1@example.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('a2@example.com').last);
    await tester.pumpAndSettle();
    await tester.enterText(_field('A'), 'ada@example.com');
    await _after5s(tester);
    expect(gmail.draftCalls, isEmpty);
    expect(other.drafts.values.single.from, 'a2@example.com');
  });

  _onMac('a Bozza that cannot be opened (offline, body not here) says so', (
    tester,
  ) async {
    await _start(tester);
    gmail.deliverDraft(
      const OutgoingMessage(
        messageId: '<altrove@example.com>',
        from: 'a1@example.com',
        to: ['ada@example.com'],
        subject: 'Dal telefono',
        body: '<p>Ciao</p>',
      ),
    );
    h.clock.advance(pollEvery); // a Bozza raises no signal: the poll brings it
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('drafts-a1')));
    await _settle(tester);
    gmail.goOffline();
    await tester.tap(find.text('Dal telefono'));
    await _settle(tester);
    expect(find.text('Bozza non trovata'), findsOneWidget);
    expect(find.byType(PostinoComposerField), findsNothing);
  });

  _onMac('Esc closes the composition and syncs the Bozza at once', (
    tester,
  ) async {
    await _start(tester);
    await _write(tester);
    final id = _openId();
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(Routefly.currentUri.path, routePaths.posta.path);
    expect(find.byType(PostinoComposerField), findsNothing);
    expect(gmail.draftCalls, [(id, true)]);
  });

  _onMac('«Chiudi» closes the composition and syncs the Bozza at once', (
    tester,
  ) async {
    await _start(tester);
    await _write(tester);
    final id = _openId();
    await _settle(tester);
    await tester.tap(find.byTooltip('Chiudi'));
    await _settle(tester);
    expect(find.byType(PostinoComposerField), findsNothing);
    expect(gmail.draftCalls, [(id, true)]);
  });

  _onMac('the `c` key opens a new composition', (tester) async {
    await _start(tester);
    // The letters need a focus somewhere outside a text field: the first Tab stop.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pumpAndSettle();
    expect(Routefly.currentUri.pathSegments[2], 'bozza');
    expect(find.bySemanticsLabel('Nuovo messaggio'), findsOneWidget);
  });

  _onMac('the posta letter keys do nothing while the editor has the focus', (
    tester,
  ) async {
    await _start(tester);
    await tester.tap(find.text('Scrivi'));
    await tester.pumpAndSettle();
    final id = _openId();
    await tester.tap(find.byType(QuillEditor));
    await tester.pump();
    for (final key in [LogicalKeyboardKey.keyC, LogicalKeyboardKey.keyJ]) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }
    expect(_openId(), id);
  });

  _onMac(
    'a Bozza of another client with attachments is not opened: it says to edit it where it was made',
    (tester) async {
      await _start(tester);
      const altrove = OutgoingMessage(
        messageId: '<altrove@example.com>',
        from: 'a1@example.com',
        to: ['ada@example.com'],
        subject: 'Con allegato',
        body: '<p>Ciao</p>',
      );
      gmail.drafts[altrove.messageId] = altrove;
      gmail.bodies['d-1'] = MessageBody(altrove.body, BodyKind.html);
      gmail.attach('d-1', 'contratto.pdf', [1, 2, 3]);
      gmail.deliver(
        Message(
          id: 'd-1',
          messageId: altrove.messageId,
          conversationId: 't-altrove',
          labelIds: const ['DRAFT'],
          isRead: true,
          isStarred: false,
          from: altrove.from,
          to: altrove.to,
          subject: altrove.subject,
          snippet: 'Ciao',
          date: DateTime.utc(2026, 1, 1),
        ),
      );
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('drafts-a1')));
      await _settle(tester);
      await tester.tap(find.text('Con allegato'));
      await _settle(tester);

      expect(
        find.text(
          'Questa Bozza ha allegati: modificala dal client che l\'ha creata',
        ),
        findsOneWidget,
      );
      expect(find.byType(QuillEditor), findsNothing);
      expect(gmail.draftCalls, isEmpty);
    },
  );

  _onMac(
    'a reply Bozza of another client is not opened: it says to edit it where it was made',
    (tester) async {
      await _start(tester);
      gmail.deliver(msg('m-1', conversationId: 't-r', subject: 'Originale'));
      gmail.deliverDraft(
        const OutgoingMessage(
          messageId: '<r@example.com>',
          from: 'a1@example.com',
          to: ['ada@example.com'],
          subject: 'Re: Originale',
          body: '<p>Ok</p>',
        ),
        conversationId: 't-r',
      );
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('drafts-a1')));
      await _settle(tester);
      await tester.tap(find.text('Re: Originale'));
      await _settle(tester);

      expect(
        find.text(
          'Questa Bozza è una risposta: modificala dal client che l\'ha creata',
        ),
        findsOneWidget,
      );
      expect(find.byType(QuillEditor), findsNothing);
      expect(gmail.draftCalls, isEmpty);
    },
  );

  _onMac('a Bozza of another client is in the Bozze list; opened, its fields and formats are there, '
      'and an edit updates it with the same Message-ID', (tester) async {
    await _start(tester);
    // As Gmail keeps it: in a thread of its own, the body downloaded on opening.
    const altrove = OutgoingMessage(
      messageId: '<altrove@example.com>',
      from: 'a1@example.com',
      to: ['Ada Okafor <ada@example.com>'],
      cc: ['bo@example.com'],
      subject: 'Dal telefono',
      body: '<p>Ciao <strong>Ada</strong></p>',
    );
    gmail.drafts[altrove.messageId] = altrove;
    gmail.bodies['d-1'] = MessageBody(altrove.body, BodyKind.html);
    gmail.deliver(
      Message(
        id: 'd-1',
        messageId: altrove.messageId,
        conversationId: 't-altrove',
        labelIds: const ['DRAFT'],
        isRead: true,
        isStarred: false,
        from: altrove.from,
        to: altrove.to,
        cc: altrove.cc,
        subject: altrove.subject,
        snippet: 'Ciao Ada',
        date: DateTime.utc(2026, 1, 1),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('drafts-a1')));
    await _settle(tester);
    expect(find.text('Bozze'), findsWidgets);
    await tester.tap(find.text('Dal telefono'));
    await _settle(tester);

    expect(find.bySemanticsLabel('Da: a1@example.com'), findsOneWidget);
    expect(
      tester.widget<TextField>(_field('A')).controller!.text,
      'Ada Okafor <ada@example.com>',
    );
    expect(
      tester.widget<TextField>(_field('Cc')).controller!.text,
      'bo@example.com',
    );
    expect(
      tester.widget<TextField>(_field('Oggetto')).controller!.text,
      'Dal telefono',
    );
    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    expect(editor.controller.document.toDelta().toJson(), [
      {'insert': 'Ciao '},
      {
        'insert': 'Ada',
        'attributes': {'bold': true},
      },
      {'insert': '\n'},
    ]);
    expect(gmail.draftCalls, isEmpty);
    // Saved once, the Bozza stays with its Account: the sender shows but no longer opens.
    expect(
      find.semantics.byLabel('Da: a1@example.com'),
      isSemantics(isEnabled: false),
    );
    await tester.tap(find.bySemanticsLabel('Da: a1@example.com'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);

    await tester.enterText(_field('Oggetto'), 'Dal telefono, poi dal Mac');
    await _after5s(tester);
    expect(gmail.draftCalls, [('<altrove@example.com>', false)]);
    expect(
      gmail.drafts['<altrove@example.com>']!.body,
      contains('<strong>Ada</strong>'),
    );
  });

  _onMac(
    'a Bozza deleted elsewhere: the local edit is dropped in silence after 5 s',
    (tester) async {
      await _start(tester);
      await _write(tester);
      final id = _openId();
      await _after5s(tester);
      expect(gmail.draftCalls, [(id, true)]);

      // Deleted elsewhere, unnoticed yet (no change signal): the edit goes out as an update.
      gmail.dropSignal();
      gmail.removeDraftRemotely(id);
      await tester.enterText(_field('Oggetto'), 'Troppo tardi');
      await _after5s(tester);
      expect(gmail.draftCalls, [(id, true), (id, false)]);
      expect(gmail.drafts, isEmpty);
      // The Bozze list no longer has it, and nothing complained.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('drafts-a1')));
      await _settle(tester);
      // The signal back: the sync also forgets the Provider's copy of it.
      gmail.restoreSignal();
      await _settle(tester);
      expect(find.text('Nessuna bozza'), findsOneWidget);
      expect(find.byType(PostinoBanner), findsNothing);
    },
  );

  _onMac(
    'offline the Bozza waits in the queue and leaves when the network returns',
    (tester) async {
      await _start(tester);
      h.connectivity.online = false;
      gmail.goOffline();
      await _write(tester);
      final id = _openId();
      await _after5s(tester);
      expect(gmail.draftCalls, isEmpty);
      expect(find.text('Saluti'), findsWidgets);

      h.clock.advance(const Duration(seconds: 1));
      gmail.goOnline();
      h.connectivity.online = true;
      await _settle(tester);
      expect(gmail.draftCalls, [(id, true)]);
    },
  );

  _onMac(
    'every control has its name, and Tab from Oggetto lands in the editor',
    (tester) async {
      await _start(tester);
      await tester.tap(find.text('Scrivi'));
      await _settle(tester);
      for (final label in [
        'Da: a1@example.com',
        'A',
        'Cc',
        'Ccn',
        'Oggetto',
        'Corpo del messaggio',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      for (final label in [
        'Grassetto',
        'Corsivo',
        'Sottolineato',
        'Barrato',
        'Link',
        'Elenco puntato',
        'Elenco numerato',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      expect(find.byTooltip('Chiudi'), findsOneWidget);
      await tester.tap(_field('Oggetto'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(primaryFocus?.debugLabel, 'Editor');
    },
  );

  _onMac(
    'Escape in the link dialog closes only the dialog, not the composition',
    (tester) async {
      await _start(tester);
      await tester.tap(find.text('Scrivi'));
      await _settle(tester);
      await tester.tap(find.byType(QuillEditor));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();
      expect(find.text('Indirizzo del link'), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Indirizzo del link'), findsNothing);
      expect(find.byType(PostinoComposerLayout), findsOneWidget);
    },
  );

  _onMac('on a low window the composition scrolls instead of overflowing', (
    tester,
  ) async {
    await _start(tester, size: const Size(390, 400));
    await tester.tap(find.text('Scrivi'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(QuillEditor)).height,
      greaterThanOrEqualTo(100),
    );
  });

  _onMac(
    'under 900 px the composition fills the window, with the back button',
    (tester) async {
      await _start(tester, size: _phone);
      await tester.tap(find.text('Scrivi'));
      await _settle(tester);
      expect(find.byType(PostinoMessageList), findsNothing);
      expect(
        tester.getSize(find.byType(PostinoComposerLayout)).width,
        _phone.width,
      );
      await tester.tap(icon(PostinoIcons.arrowLeft));
      await _settle(tester);
      expect(find.byType(PostinoComposerLayout), findsNothing);
      expect(find.byType(PostinoMessageList), findsOneWidget);
    },
  );
}
