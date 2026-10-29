// Atoms and molecules: one golden each (light and dark × text 100% and 200%) and the accessibility guidelines.
// ponytail: the design system fonts are not bundled yet, so goldens render with the test font.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

const _golden = ValueKey('golden');
const _sky = (color: PostinoAccountColor.sky, initial: 'L');

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
    ],
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
    ],
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
  'empty_state': () => const PostinoEmptyState(
    title: 'Niente di nuovo',
    body: 'I messaggi compaiono qui appena arrivano.',
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

void main() {
  for (final MapEntry(key: name, value: build) in _components.entries) {
    testWidgets('$name matches its golden and the guidelines', (tester) async {
      tester.view
        ..physicalSize = const Size(720, 3200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(_grid(build));
      await expectLater(
        find.byKey(_golden),
        matchesGoldenFile('goldens/$name.png'),
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    });
  }

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
