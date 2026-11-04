// Screen readers on the list and the Conversazione (#55): row labels, message headers, «…», the image
// banner and blocked images, the announcement on opening, and Flutter's accessibility guidelines.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

void _mailbox(FakeMailProvider p) {
  p
    ..bodies['r1'] = const MessageBody('Prima risposta\n\n> Testo citato', BodyKind.testo)
    ..bodies['r2'] = const MessageBody(
      '<p>Il logo:</p><img src="https://img.example/logo.png" alt="Logo"><img src="https://img.example/x.png">',
      BodyKind.html,
    )
    ..deliver(
      msg(
        'r1',
        conversationId: 'r',
        fromName: 'Ada Okafor',
        subject: 'Preventivo',
        snippet: 'Prima risposta',
        isRead: true,
        date: DateTime.utc(2026, 10, 1, 9),
      ),
    )
    ..deliver(
      msg(
        'r2',
        conversationId: 'r',
        fromName: 'Bruno Bianchi',
        subject: 'Preventivo',
        snippet: 'Il logo',
        isStarred: true,
        date: DateTime.utc(2026, 10, 2, 9),
      ),
    );
}

Future<void> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(800, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  _mailbox(await h.addAccount('a1'));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('row-a1-r2')));
  await tester.pumpAndSettle();
}

Finder _in(String id, Finder f) => find.descendant(of: find.byKey(ValueKey('message-$id')), matching: f);

Future<void> _guidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  // Real fonts only on macOS, as for the goldens.
  if (Platform.isMacOS) await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  testWidgets('a row reads unread, sender, subject, count, preview, Stella, Account and date as one button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _start(tester);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('row-a1-r2'))),
      isSemantics(
        label: 'Non letto, Bruno Bianchi, Preventivo, 2 messaggi, Il logo, con Stella, account a1@example.com, 2 ott',
        isButton: true,
        hasTapAction: true,
      ),
    );
    await _guidelines(tester);
    semantics.dispose();
  });

  testWidgets('opening a Conversazione announces its subject and number of messages', (tester) async {
    final semantics = tester.ensureSemantics();
    await _start(tester);
    tester.takeAnnouncements();
    await _open(tester);
    expect(tester.takeAnnouncements(), [isAccessibilityAnnouncement('Preventivo, 2 messaggi')]);
    semantics.dispose();
  });

  testWidgets('message headers are buttons with their expanded state, read before the body', (tester) async {
    final semantics = tester.ensureSemantics();
    await _start(tester);
    await _open(tester);
    final header = _in('r1', find.bySemanticsLabel(RegExp('^Ada Okafor')));
    expect(
      tester.getSemantics(header),
      matchesSemantics(
        label: 'Ada Okafor\nPrima risposta\n1 ott',
        isButton: true,
        hasExpandedState: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(header), isSemantics(isButton: true, hasExpandedState: true, isExpanded: true));
    // The body is its own node, after the header in reading order.
    final node = tester.getSemantics(header);
    final body = tester.getSemantics(_in('r1', find.bySemanticsLabel('Prima risposta')));
    expect(body.label, 'Prima risposta');
    final order = node.parent!.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder);
    expect(order.indexOf(node), lessThan(order.indexOf(body)));
    semantics.dispose();
  });

  testWidgets('an unread header starts with «Non letto», a read one does not', (tester) async {
    final semantics = tester.ensureSemantics();
    Widget message({required bool unread}) => MaterialApp(
      theme: PostinoTheme.light(),
      home: Scaffold(
        body: PostinoThreadMessage(
          sender: 'Bruno Bianchi',
          time: '10:05',
          preview: 'Il logo',
          expanded: false,
          onToggle: () {},
          body: const SizedBox(),
          unread: unread,
          unreadLabel: 'Non letto',
        ),
      ),
    );
    await tester.pumpWidget(message(unread: true));
    expect(find.bySemanticsLabel('Non letto\nBruno Bianchi\nIl logo\n10:05'), findsOneWidget);
    await tester.pumpWidget(message(unread: false));
    expect(find.bySemanticsLabel('Bruno Bianchi\nIl logo\n10:05'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('«…» says whether the quote is shown', (tester) async {
    final semantics = tester.ensureSemantics();
    await _start(tester);
    await _open(tester);
    await tester.tap(_in('r1', find.bySemanticsLabel(RegExp('^Ada Okafor'))));
    await tester.pumpAndSettle();
    final toggle = _in('r1', find.bySemanticsLabel('Mostra testo citato'));
    expect(tester.getSemantics(toggle), isSemantics(isButton: true, hasExpandedState: true, isExpanded: false));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(toggle), isSemantics(isButton: true, hasExpandedState: true, isExpanded: true));
    semantics.dispose();
  });

  testWidgets('the image banner and the blocked images are labelled', (tester) async {
    final semantics = tester.ensureSemantics();
    await _start(tester);
    await _open(tester);
    expect(
      tester.getSemantics(_in('r2', find.bySemanticsLabel(RegExp('^Immagini remote bloccate')))),
      isSemantics(isLiveRegion: true),
    );
    expect(_in('r2', find.bySemanticsLabel('Immagine bloccata: Logo')), findsOneWidget);
    expect(_in('r2', find.bySemanticsLabel('Immagine bloccata')), findsOneWidget);
    await _guidelines(tester);
    semantics.dispose();
  });
}
