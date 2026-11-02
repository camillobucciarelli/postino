// Atoms and molecules: one golden each (light and dark × text 100% and 200%) and the accessibility guidelines.
// ponytail: the design system fonts are not bundled yet, so goldens render with the test font.
// ponytail: goldens are recorded and compared only on macOS (developers and the self-hosted Apple runner):
// Linux CI rasterises text and anti-aliasing differently (1-2% of pixels); the tap target guidelines still run everywhere.
// The text contrast guideline samples the rendered pixels too (the most frequent light and dark colour around
// each text): on Linux a small caption has no solid ink pixel winning over its anti-aliasing, so it runs on macOS only.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

const _golden = ValueKey('golden');
void _noop() {}
const _sky = (color: PostinoAccountColor.sky, initial: 'L');
const _rose = (color: PostinoAccountColor.rose, initial: 'P');
const _senders = <PostinoSenderOption>[
  (id: 'a1', mark: _sky, address: 'lavoro@example.com'),
  (id: 'a2', mark: _rose, address: 'personale@example.com'),
];
const _formats = PostinoFormatLabels(
  bold: 'Grassetto',
  italic: 'Corsivo',
  underline: 'Sottolineato',
  strikethrough: 'Barrato',
  link: 'Link',
  bulletList: 'Elenco puntato',
  numberedList: 'Elenco numerato',
  linkUrl: 'Indirizzo del link',
  insert: 'Inserisci',
  cancel: 'Annulla',
);

/// A document with every format of #35.
QuillController _document() => QuillController(
  document: Document.fromJson([
    {'insert': 'Ciao '},
    {
      'insert': 'Ada',
      'attributes': {'bold': true},
    },
    {'insert': ', '},
    {
      'insert': 'corsivo',
      'attributes': {'italic': true},
    },
    {'insert': ' '},
    {
      'insert': 'sottolineato',
      'attributes': {'underline': true},
    },
    {'insert': ' '},
    {
      'insert': 'barrato',
      'attributes': {'strike': true},
    },
    {'insert': ' '},
    {
      'insert': 'link',
      'attributes': {'link': 'https://example.com'},
    },
    {'insert': '\npunto'},
    {
      'insert': '\n',
      'attributes': {'list': 'bullet'},
    },
    {'insert': 'uno'},
    {
      'insert': '\n',
      'attributes': {'list': 'ordered'},
    },
  ]),
  selection: const TextSelection.collapsed(offset: 0),
);

PostinoRichEditor _editor() => PostinoRichEditor(
  controller: _document(),
  label: 'Corpo del messaggio',
  placeholder: 'Scrivi il messaggio',
  labels: _formats,
);

final _components = <String, Widget Function()>{
  'icon': () => Wrap(
    spacing: 8,
    children: [
      for (final i in [
        PostinoIcons.inbox,
        PostinoIcons.inboxAll,
        PostinoIcons.tag,
        PostinoIcons.star,
        PostinoIcons.key,
        PostinoIcons.cloudOff,
        PostinoIcons.refresh,
        PostinoIcons.alert,
        PostinoIcons.check,
        PostinoIcons.menu,
        PostinoIcons.arrowLeft,
        PostinoIcons.chevronLeft,
        PostinoIcons.image,
        PostinoIcons.pencil,
        PostinoIcons.close,
        PostinoIcons.bold,
        PostinoIcons.italic,
        PostinoIcons.underline,
        PostinoIcons.strikethrough,
        PostinoIcons.link,
        PostinoIcons.listBullet,
        PostinoIcons.listNumbered,
        PostinoIcons.send,
        PostinoIcons.download,
        PostinoIcons.moreVertical,
      ])
        PostinoIcon(i, size: PostinoSize.iconLg),
      const PostinoIcon(PostinoIcons.star, filled: true, label: 'Stella'),
    ],
  ),
  'account_mark': () => Wrap(
    spacing: 8,
    children: [
      for (final c in PostinoAccountColor.values)
        PostinoAccountMark(color: c, initial: c.name[0].toUpperCase()),
      const PostinoAccountMark(
        color: PostinoAccountColor.rose,
        initial: 'P',
        size: 16,
      ),
      const PostinoAccountMark(
        color: PostinoAccountColor.olive,
        initial: 'A',
        size: 40,
        label: 'Account Atlas',
      ),
    ],
  ),
  'avatar': () => const Row(
    spacing: 16,
    children: [
      PostinoAvatar(name: 'Ada Okafor'),
      PostinoAvatar(
        name: 'Marco Lenti',
        badge: PostinoAccountMark(
          color: PostinoAccountColor.rose,
          initial: 'P',
          size: 16,
        ),
      ),
    ],
  ),
  'button': () => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      PostinoButton(label: 'Collega Gmail', onPressed: () {}),
      PostinoButton(
        label: 'Aggiungi account',
        onPressed: () {},
        size: PostinoButtonSize.lg,
      ),
      PostinoButton(
        label: 'Riprova',
        onPressed: () {},
        variant: PostinoButtonVariant.ghost,
      ),
    ],
  ),
  'icon_button': () => PostinoIconButton(
    icon: PostinoIcons.menu,
    label: 'Apri menu',
    onPressed: () {},
  ),
  'skeleton': () => const PostinoSkeleton(label: 'Caricamento', rows: 2),
  'message_tile': () => const Column(
    children: [
      PostinoMessageTile(
        sender: 'Ada Okafor',
        subject: 'Contratto Rossi: versione firmata',
        preview: 'Ti giro il PDF firmato, manca solo la tua sigla.',
        time: '09:42',
        unread: true,
        starred: true,
        account: _sky,
        semanticLabel: 'Non letto, Ada Okafor',
      ),
      PostinoMessageTile(
        sender: 'Luca Neri',
        subject: 'Call di giovedì spostata alle 15',
        preview: 'Ci vediamo alle 15 invece che alle 11.',
        time: 'Ieri',
        unread: false,
        starred: false,
        semanticLabel: 'Luca Neri',
      ),
      PostinoMessageTile(
        sender: 'Bruno Verdi',
        subject: 'Re: Cena di venerdì',
        preview: 'Alle 20 da Mario, porto io il vino.',
        time: 'lun',
        unread: false,
        starred: false,
        count: 3,
        selected: true,
        onTap: _noop,
        semanticLabel: 'Bruno Verdi, 3 messaggi',
      ),
    ],
  ),
  'thread_message': () => Column(
    children: [
      PostinoThreadMessage(
        sender: 'Bruno Verdi',
        time: '10:05',
        preview: 'Perfetto',
        recipients: 'a me, cc Marco Lenti',
        details: const [
          PostinoMessageDetail('Da', 'bruno@example.com'),
          PostinoMessageDetail('A', 'me@example.com'),
          PostinoMessageDetail('Data', 'lunedì 5 ottobre 2026, 09:42'),
          PostinoMessageDetail('Ricevuto su', 'me@example.com', account: _sky),
        ],
        notices: [
          PostinoBanner(
            tone: PostinoBannerTone.info,
            icon: PostinoIcons.image,
            title: 'Immagini remote bloccate',
            message:
                'Caricarle direbbe al mittente che hai aperto il messaggio.',
            spaced: false,
            actionLabel: 'Mostra immagini',
            onAction: _noop,
            secondaryActionLabel: 'Sempre da questo mittente',
            onSecondaryAction: _noop,
          ),
        ],
        expanded: true,
        onToggle: () {},
        body: PostinoMessageBody.missing(
          note: 'Corpo non disponibile offline',
          actionLabel: 'Riprova',
          onAction: () {},
        ),
      ),
      PostinoThreadMessage(
        sender: 'Ada Okafor',
        address: 'ada@okafor-legal.it',
        time: '09:42',
        preview: 'Sì, alle 20.',
        recipients: 'a Bruno Verdi, cc Marco Lenti',
        unread: true,
        expanded: true,
        onToggle: () {},
        body: const PostinoMessageBody(
          text: 'Ciao Bruno,\nsì, alle 20 da Mario. Porto io il dolce.',
        ),
        signature: const PostinoMessageBody(
          text: '-- \nAda Okafor\nOkafor Legal · Via Dante 12, Milano',
          quiet: true,
        ),
        quote: const PostinoMessageBody(
          text:
              'Il giorno lun 5 ott, Bruno Verdi ha scritto:\n> Ti va una cena?',
          quiet: true,
        ),
        quoteLabel: 'Mostra testo citato',
      ),
      PostinoThreadMessage(
        sender: 'Bruno Verdi',
        time: 'lun',
        preview: 'Ti va una cena venerdì?',
        expanded: false,
        onToggle: () {},
        body: const SizedBox(),
      ),
    ],
  ),
  'thread_view': () => SizedBox(
    height: 220,
    child: PostinoThreadView(
      subject: 'Revisione trimestrale: numeri finali',
      importantLabel: 'Importante',
      account: _sky,
      accountName: 'lavoro@example.com',
      labels: const ['Progetti', 'Fatture'],
      messages: [
        PostinoThreadMessage(
          sender: 'Bruno Verdi',
          time: '10:05',
          preview: 'Perfetto',
          expanded: false,
          onToggle: () {},
          body: const SizedBox(),
        ),
      ],
    ),
  ),
  'banner': () => Column(
    children: [
      PostinoBanner(
        tone: PostinoBannerTone.warning,
        icon: PostinoIcons.key,
        account: _sky,
        title: 'Lavoro è da ricollegare',
        message: 'Google non accetta più l’accesso.',
        actionLabel: 'Accedi',
        onAction: () {},
      ),
      const PostinoBanner(
        tone: PostinoBannerTone.offline,
        title: 'Sei offline',
        message: 'La posta si aggiornerà al ritorno della rete.',
      ),
      const PostinoBanner(
        tone: PostinoBannerTone.danger,
        title: 'Collegamento non riuscito',
        message: 'Nessuna connessione: riprova quando sei online.',
      ),
      PostinoBanner(
        tone: PostinoBannerTone.info,
        icon: PostinoIcons.image,
        title: 'Immagini remote bloccate',
        actionLabel: 'Mostra immagini',
        onAction: _noop,
        secondaryActionLabel: 'Sempre da questo mittente',
        onSecondaryAction: _noop,
      ),
    ],
  ),
  'html_card': () => PostinoHtmlCard(
    html:
        '<h2 style="color: #1a1a1a">Novità</h2><p>Ciao, ecco le '
        '<a href="https://example.com">notizie</a> della settimana.</p>'
        '<img alt="Logo">',
    onTapUrl: (_) {},
  ),
  'sync_status': () => const Wrap(
    spacing: 16,
    children: [
      PostinoSyncStatus(
        state: PostinoSyncState.reconnect,
        label: 'Da ricollegare',
      ),
      PostinoSyncStatus(state: PostinoSyncState.offline, label: 'Offline'),
      PostinoSyncStatus(
        state: PostinoSyncState.reconnect,
        label: 'Da ricollegare',
        compact: true,
      ),
    ],
  ),
  'attachment_chip': () => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      PostinoAttachmentChip(
        name: 'Contratto_Rossi.pdf',
        size: '1,2 MB',
        onOpen: _noop,
        moreLabel: 'Altre azioni',
        saveLabel: 'Salva…',
        onSave: _noop,
      ),
      PostinoAttachmentChip(
        name: 'Budget_2027.xlsx',
        size: '88 KB',
        onOpen: _noop,
        progress: 0.42,
        progressLabel: 'Scaricamento… 42%',
        cancelLabel: 'Annulla scaricamento',
        onCancel: _noop,
      ),
      PostinoAttachmentChip(
        name: 'Foto_cantiere.jpg',
        size: '3,4 MB',
        onOpen: _noop,
        error: 'Offline: allegato non ancora scaricato',
        retryLabel: 'Riprova',
      ),
    ],
  ),
  'empty_state': () => const PostinoEmptyState(
    title: 'Niente di nuovo',
    body: 'I messaggi compaiono qui appena arrivano.',
  ),
  'composer_field': () => Column(
    children: [
      PostinoComposerField(
        label: 'A',
        controller: TextEditingController(text: 'ada@okafor-legal.it'),
      ),
      PostinoComposerField(
        label: 'Oggetto',
        controller: TextEditingController(),
        trailing: PostinoButton(
          label: 'Cc',
          variant: PostinoButtonVariant.ghost,
          size: PostinoButtonSize.sm,
          onPressed: _noop,
        ),
      ),
    ],
  ),
  'sender_picker': () => PostinoSenderPicker(
    options: _senders,
    selectedId: 'a1',
    onSelected: (_) {},
    label: 'Da',
  ),
  'format_button': () => Row(
    children: [
      PostinoFormatButton(
        icon: PostinoIcons.bold,
        label: 'Grassetto',
        active: true,
        onPressed: _noop,
      ),
      PostinoFormatButton(
        icon: PostinoIcons.italic,
        label: 'Corsivo',
        active: false,
        onPressed: _noop,
      ),
    ],
  ),
  'rich_editor': () => SizedBox(height: 260, child: _editor()),
  'fab': () =>
      PostinoFab(label: 'Scrivi', icon: PostinoIcons.pencil, onPressed: _noop),
  'composer_layout': () => SizedBox(
    height: 520,
    child: PostinoComposerLayout(
      sender: PostinoSenderPicker(
        options: _senders,
        selectedId: 'a2',
        onSelected: (_) {},
        label: 'Da',
      ),
      fields: [
        PostinoComposerField(
          label: 'A',
          controller: TextEditingController(text: 'ada@okafor-legal.it'),
        ),
        PostinoComposerField(
          label: 'Oggetto',
          controller: TextEditingController(text: 'Contratto Rossi'),
        ),
      ],
      editor: _editor(),
    ),
  ),
};

/// Light and dark side by side, text at 100% over 200%.
Widget _grid(Widget Function() build) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: PostinoTheme.light(),
  home: Align(
    alignment: Alignment.topLeft,
    child: RepaintBoundary(
      key: _golden,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final theme in [PostinoTheme.light(), PostinoTheme.dark()])
            Theme(
              data: theme,
              child: Builder(
                builder: (context) => Container(
                  width: 360,
                  color: context.pc.surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final scale in [1.0, 2.0])
                        MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.linear(scale),
                            disableAnimations: true,
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: build(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  ),
);

/// The editor as on macOS, where the composer is QA'd: on touch platforms quill arms a long press
/// on the link's own text run (an inline link, which the 48px rule exempts) that the tap target
/// guideline would flag.
const _desktop = {'rich_editor', 'composer_layout'};

void main() {
  for (final MapEntry(key: name, value: build) in _components.entries) {
    testWidgets('$name matches its golden and the guidelines', (tester) async {
      tester.view
        ..physicalSize = const Size(720, 3200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      if (_desktop.contains(name)) {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      }
      try {
        await tester.pumpWidget(_grid(build));
        if (Platform.isMacOS) {
          await expectLater(
            find.byKey(_golden),
            matchesGoldenFile('goldens/$name.png'),
          );
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      semantics.dispose();
    });
  }

  testWidgets('the recipients open the details of a message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PostinoTheme.light(),
        home: Scaffold(
          body: PostinoThreadMessage(
            sender: 'bruno@example.com',
            time: '10:05',
            preview: 'Perfetto',
            recipients: 'a me',
            details: const [
              PostinoMessageDetail('Ricevuto su', 'me@example.com'),
            ],
            expanded: true,
            onToggle: () {},
            body: const SizedBox(),
          ),
        ),
      ),
    );
    expect(find.text('Ricevuto su'), findsNothing);
    await tester.tap(find.text('a me'));
    await tester.pumpAndSettle();
    expect(find.text('Ricevuto su'), findsOneWidget);
    expect(find.text('me@example.com', findRichText: true), findsOneWidget);
  });

  testWidgets(
    'the recipients toggle is a focusable button: Enter and semantic tap open the details',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: PostinoTheme.light(),
          home: Scaffold(
            body: PostinoThreadMessage(
              sender: 'bruno@example.com',
              time: '10:05',
              preview: 'Perfetto',
              recipients: 'a me',
              details: const [
                PostinoMessageDetail('Ricevuto su', 'me@example.com'),
              ],
              expanded: true,
              onToggle: () {},
              body: const SizedBox(),
            ),
          ),
        ),
      );
      final target = tester.getRect(
        find.byKey(const ValueKey('recipients-target')),
      );
      expect(target.height, greaterThanOrEqualTo(48));
      expect(
        tester.getCenter(find.text('a me')).dy,
        moreOrLessEquals(target.center.dy, epsilon: 1),
      );
      final toggle = find.byKey(const ValueKey('recipients-toggle'));
      // Tab reaches it, Enter opens.
      // The header takes the first Tab, the toggle the second.
      for (var i = 0; i < 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.ancestor(
          of: find.byElementPredicate((e) => e == focused),
          matching: toggle,
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Ricevuto su'), findsOneWidget);
      // Semantic tap closes it again.
      tester.semantics.tap(find.semantics.byLabel('a me'));
      await tester.pumpAndSettle();
      expect(find.text('Ricevuto su'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('the quote toggle exposes a semantic tap action', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: PostinoTheme.light(),
        home: Scaffold(
          body: PostinoThreadMessage(
            sender: 'bruno@example.com',
            time: '10:05',
            preview: 'Perfetto',
            expanded: true,
            onToggle: () {},
            body: const SizedBox(),
            quote: const Text('citato'),
            quoteLabel: 'Mostra testo citato',
          ),
        ),
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('Mostra testo citato'));
    await tester.pumpAndSettle();
    expect(find.text('citato'), findsOneWidget);
    semantics.dispose();
  });

  group('PostinoMessageList', () {
    Widget list({required bool loading, int count = 0}) => MaterialApp(
      theme: PostinoTheme.light(),
      home: Scaffold(
        body: PostinoMessageList(
          loading: loading,
          itemCount: count,
          itemBuilder: (_, i) => Text('row $i'),
          onRefresh: () async {},
          loadingLabel: 'Caricamento',
          emptyTitle: 'Niente di nuovo',
        ),
      ),
    );

    testWidgets('the first load shows the Skeleton', (tester) async {
      await tester.pumpWidget(list(loading: true));
      expect(find.byType(PostinoSkeleton), findsOneWidget);
      expect(find.byType(PostinoEmptyState), findsNothing);
    });

    testWidgets('an empty list shows the EmptyState', (tester) async {
      await tester.pumpWidget(list(loading: false));
      expect(find.byType(PostinoEmptyState), findsOneWidget);
      expect(find.byType(PostinoSkeleton), findsNothing);
    });

    testWidgets('rows replace both', (tester) async {
      await tester.pumpWidget(list(loading: false, count: 2));
      expect(find.text('row 1'), findsOneWidget);
      expect(find.byType(PostinoEmptyState), findsNothing);
    });
  });
}
