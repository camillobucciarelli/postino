// #53: every interactive component shows the focus ring when it has keyboard focus;
// at text 200% lists, headers and components wrap instead of cutting, and nothing overflows.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

void _noop() {}
const _sky = (color: PostinoAccountColor.sky, initial: 'L');
const _long =
    'Revisione del preventivo per la ristrutturazione della cucina e del bagno al piano terra';

Widget _app(Widget child, {double scale = 1, ThemeData? theme}) => MaterialApp(
  theme: theme ?? PostinoTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child,
    ),
  ),
);

PostinoThreadMessage _message({bool expanded = true}) => PostinoThreadMessage(
  sender: 'Bruno Bianchi della Valle Superiore',
  address: 'bruno.bianchi.dellavalle@example.com',
  time: '10:05',
  preview: _long,
  recipients: 'a me, cc Marco Rossi, Lucia Verdi, Giovanni Neri e altri tre',
  details: const [PostinoMessageDetail('Ricevuto su', 'me@example.com')],
  expanded: expanded,
  onToggle: _noop,
  body: const PostinoMessageBody(text: 'Ciao'),
  quote: const Text('citato'),
  quoteLabel: 'Mostra testo citato',
);

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

/// The whole composer, with a long address and subject.
Widget _composer() => PostinoComposerLayout(
  sender: PostinoSenderPicker(
    options: const [
      (id: 1, mark: _sky, address: 'lucia.bianchi.della.valle@example.com'),
    ],
    selectedId: 1,
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
      controller: TextEditingController(text: _long),
      trailing: PostinoButton(
        label: 'Cc',
        variant: PostinoButtonVariant.ghost,
        size: PostinoButtonSize.sm,
        onPressed: _noop,
      ),
    ),
  ],
  editor: PostinoRichEditor(
    controller: QuillController.basic(),
    label: 'Corpo del messaggio',
    placeholder: 'Scrivi il messaggio',
    labels: _formats,
  ),
);

final _drawer = PostinoNavigationDrawer(
  sections: [
    PostinoDrawerSection(
      items: [
        PostinoDrawerItem(
          key: const ValueKey('active'),
          label: 'Posta in arrivo',
          icon: PostinoIcons.inbox,
          active: true,
          onTap: _noop,
        ),
        PostinoDrawerItem(
          key: const ValueKey('other'),
          label: 'Tutte le etichette del lavoro e dei progetti personali',
          account: _sky,
          onTap: _noop,
        ),
      ],
    ),
  ],
);

/// Tabs until the primary focus is inside [target].
Future<void> _tabTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 12; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null &&
        find
            .ancestor(
              of: find.byElementPredicate((e) => e == focused),
              matching: target,
            )
            .evaluate()
            .isNotEmpty) {
      return;
    }
  }
  fail('Tab never reached $target');
}

CustomPainter? _ring(WidgetTester tester, Finder target) => tester
    .widget<CustomPaint>(
      find
          .descendant(
            of: find
                .descendant(of: target, matching: find.byType(PostinoFocusRing))
                .first,
            matching: find.byType(CustomPaint),
          )
          .first,
    )
    .foregroundPainter;

void main() {
  group('focus ring', () {
    final cases = <String, (Widget, Finder)>{
      'primary button': (
        PostinoButton(label: 'Accedi', onPressed: _noop),
        find.byType(FilledButton),
      ),
      'ghost button': (
        PostinoButton(
          label: 'Riprova',
          onPressed: _noop,
          variant: PostinoButtonVariant.ghost,
        ),
        find.byType(TextButton),
      ),
      'icon button': (
        PostinoIconButton(
          icon: PostinoIcons.menu,
          label: 'Menu',
          onPressed: _noop,
        ),
        find.byType(IconButton),
      ),
      'message tile': (
        PostinoMessageTile(
          sender: 'Bruno',
          subject: 'Preventivo',
          preview: 'Ciao',
          time: '09:42',
          unread: true,
          starred: true,
          semanticLabel: 'Bruno',
          selected: true,
          onTap: _noop,
        ),
        find.byType(InkWell),
      ),
      'thread message header': (_message(), find.byType(InkWell).first),
      'recipients toggle': (
        _message(),
        find.byKey(const ValueKey('recipients-toggle')),
      ),
      'quote toggle': (_message(), find.byKey(const ValueKey('quote-toggle'))),
      'drawer item': (_drawer, find.byKey(const ValueKey('other'))),
      'active drawer item': (_drawer, find.byKey(const ValueKey('active'))),
      'sender picker': (_composer(), find.byType(PostinoSenderPicker)),
      'format button': (_composer(), find.byType(PostinoFormatButton).first),
      'fab': (
        PostinoFab(
          label: 'Scrivi',
          icon: PostinoIcons.pencil,
          onPressed: _noop,
        ),
        find.byType(PostinoFab),
      ),
    };
    for (final MapEntry(key: name, value: (widget, target)) in cases.entries) {
      for (final (theme, data) in [
        ('light', PostinoTheme.light()),
        ('dark', PostinoTheme.dark()),
      ]) {
        testWidgets('$name shows it with keyboard focus ($theme)', (
          tester,
        ) async {
          await tester.pumpWidget(
            _app(
              Scaffold(body: Center(child: widget)),
              theme: data,
            ),
          );
          expect(_ring(tester, target), isNull);
          await _tabTo(tester, target);
          final ring = _ring(tester, target);
          expect(ring, isNotNull);
          expect(
            (Canvas canvas) => ring!.paint(canvas, const Size(40, 40)),
            paints..rrect(
              color: data.extension<PostinoColors>()!.focusRing,
              strokeWidth: PostinoBorder.borderWidthFocus,
              style: PaintingStyle.stroke,
            ),
          );
        });
      }
    }
  });

  testWidgets('a composer field marks its focus on the hairline', (
    tester,
  ) async {
    await tester.pumpWidget(_app(Scaffold(body: _composer())));
    final c = PostinoTheme.light().extension<PostinoColors>()!;
    BorderSide bottom() =>
        ((tester
                            .widget<Container>(
                              find
                                  .descendant(
                                    of: find.byType(PostinoComposerField).first,
                                    matching: find.byType(Container),
                                  )
                                  .first,
                            )
                            .decoration
                        as BoxDecoration)
                    .border
                as Border)
            .bottom;
    expect(bottom().color, c.composerFieldDivider);
    await _tabTo(tester, find.byType(PostinoComposerField).first);
    expect(bottom().color, c.inputBorderFocus);
    expect(bottom().width, PostinoBorder.borderWidthFocus);
  });

  group('text at 200%', () {
    final screens = <String, Widget>{
      'message list': ListView(
        children: [
          for (final unread in [true, false])
            PostinoMessageTile(
              sender: 'Bruno Bianchi della Valle Superiore',
              subject: _long,
              preview: '$_long. $_long',
              time: '09:42',
              unread: unread,
              starred: true,
              semanticLabel: 'Bruno',
              account: _sky,
              count: 3,
              onTap: _noop,
            ),
        ],
      ),
      'thread view': PostinoThreadView(
        subject: _long,
        account: _sky,
        accountName: 'Lavoro di Lucia, account aziendale principale',
        labels: const ['Fatture e ricevute del condominio', 'Casa'],
        messages: [_message(expanded: false), _message()],
      ),
      'drawer': _drawer,
      'label chip': const Wrap(
        children: [
          PostinoLabelChip(
            name: 'Fatture e ricevute del condominio di via Roma',
          ),
        ],
      ),
      'composer': _composer(),
      'fab': Align(
        alignment: Alignment.bottomRight,
        child: PostinoFab(
          label: 'Scrivi un nuovo messaggio',
          icon: PostinoIcons.pencil,
          onPressed: _noop,
        ),
      ),
    };
    for (final MapEntry(key: name, value: body) in screens.entries) {
      for (final width in [390.0, 1280.0]) {
        testWidgets('$name wraps without overflow at $width', (tester) async {
          tester.view
            ..physicalSize = Size(width, 2400)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _app(
              PostinoSinglePaneLayout(
                appBar: const PostinoAppBar(
                  title: 'Fatture e ricevute del condominio',
                  subtitle: 'Lavoro di Lucia, account aziendale principale',
                  account: _sky,
                ),
                body: body,
              ),
              scale: 2,
            ),
          );
          // A layout overflow fails the test on its own; here: no text cut by maxLines.
          final cut = tester.allRenderObjects
              .whereType<RenderParagraph>()
              .where(
                // Avatar and AccountMark initials are decorative, at a fixed size.
                (p) =>
                    p.textScaler != TextScaler.noScaling &&
                    (p.didExceedMaxLines ||
                        p.overflow == TextOverflow.ellipsis),
              )
              .map((p) => p.text.toPlainText());
          expect(cut, isEmpty);
          // The bar grew around its wrapped title.
          expect(
            tester.getSize(find.byType(AppBar)).height,
            greaterThan(PostinoSize.appBarHeight),
          );
        });
      }
    }

    testWidgets('the app bar stays 56 tall at 100%', (tester) async {
      await tester.pumpWidget(
        _app(
          const PostinoSinglePaneLayout(
            appBar: PostinoAppBar(
              title: 'Posta unificata',
              subtitle: '2 account',
            ),
            body: SizedBox(),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(AppBar)).height,
        PostinoSize.appBarHeight,
      );
    });

    testWidgets('a very long title does not overflow nor cover the body', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(390, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final long = List.filled(200, 'a').join();
      await tester.pumpWidget(
        _app(
          PostinoSinglePaneLayout(
            appBar: PostinoAppBar(title: long, subtitle: long, account: _sky),
            body: const SizedBox(key: ValueKey('body')),
          ),
          scale: 2,
        ),
      );
      // A layout overflow fails the test on its own.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
      );
    });
  });
}
