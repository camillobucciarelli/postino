// PROTOTIPO (#106): the fake Postino — drawer (Etichette, Impostazioni), list + Conversazione, model banner.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:postino/design_system/molecules/postino_empty_state.dart';
import 'package:postino/design_system/molecules/postino_menu.dart' show PostinoMenuItem;
import 'package:postino/design_system/organisms/postino_app_bar.dart';
import 'package:postino/design_system/organisms/postino_navigation_drawer.dart';
import 'package:postino/design_system/templates/postino_adaptive_layout.dart';
import 'package:postino/design_system/templates/postino_list_detail_layout.dart';
import 'package:postino/design_system/tokens/postino_icons.dart';

import 'conversation.dart';
import 'ds_proposti/postino_context_menu.dart';
import 'ds_proposti/postino_labeled_message_tile.dart';
import 'ds_proposti/proto_icons.dart';
import 'label_flow.dart';
import 'model_status.dart';
import 'proto_state.dart';
import 'settings_screen.dart';

class const PostaScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Proto.of(context);
    final drawer = _drawer(s);
    void close() => s.update(() => s.openId = null);
    final open = s.open;
    // One outer Scaffold: the snackbar shows once, not on both panes.
    return Scaffold(
      body: PostinoSidebarShell(
        drawer: drawer,
        closeLabel: 'Riduci la barra laterale',
        openLabel: 'Espandi la barra laterale',
        child: s.page == ProtoPage.impostazioni
            ? SettingsScreen(drawer: drawer)
            : PostinoListDetailLayout(
                list: PostinoAdaptiveLayout(
                  appBar: PostinoAppBar(title: s.filter ?? 'Posta in arrivo', subtitle: accountName, account: account),
                  drawer: drawer,
                  banners: const [ModelBanner()],
                  body: const _ThreadList(),
                ),
                empty: const PostinoEmptyState(
                  title: 'Nessuna Conversazione aperta',
                  body: 'Scegline una dalla lista.',
                  icon: PostinoIcons.inbox,
                ),
                detail: open == null ? null : ConversationPane(key: ValueKey(open.id), thread: open, onBack: close),
                detailKey: open?.id,
                onClose: close,
                resizeLabel: 'Larghezza lista',
                resizeValueLabel: (w) => '${w.round()} pixel',
              ),
      ),
    );
  }

  Widget _drawer(ProtoState s) {
    final posta = s.page == ProtoPage.posta;
    void go(ProtoPage page, [String? filter]) => s.update(() {
      s
        ..page = page
        ..filter = filter;
    });
    return PostinoNavigationDrawer(
      sections: [
        PostinoDrawerSection(
          items: [
            PostinoDrawerItem(
              label: 'Posta in arrivo',
              icon: PostinoIcons.inbox,
              active: posta && s.filter == null,
              onTap: () => go(ProtoPage.posta),
            ),
          ],
        ),
        PostinoDrawerSection(
          title: 'Etichette',
          items: [
            for (final l in s.labels)
              PostinoDrawerItem(
                label: l.name,
                icon: PostinoIcons.tag,
                active: posta && s.filter == l.name,
                onTap: () => go(ProtoPage.posta, l.name),
              ),
          ],
        ),
        PostinoDrawerSection(
          items: [
            PostinoDrawerItem(
              label: 'Impostazioni',
              icon: ProtoIcons.settings,
              active: !posta,
              onTap: () => go(ProtoPage.impostazioni),
            ),
          ],
        ),
      ],
    );
  }
}

class const _ThreadList() extends StatefulWidget {
  @override
  State<_ThreadList> createState() => _ThreadListState();
}

class _ThreadListState() extends State<_ThreadList> {
  final _focus = <String, FocusNode>{};

  @override
  void dispose() {
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Proto.of(context);
    final shown = s.threads.where((t) => s.filter == null || t.labels.contains(s.filter)).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 160), // room for the prototype bar
      children: [
        for (final t in shown)
          Builder(
            key: ValueKey(t.id),
            builder: (row) {
              final focus = _focus.putIfAbsent(t.id, () => FocusNode(debugLabel: t.subject));
              final names = t.labels.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              return PostinoContextMenu(
                items: [
                  PostinoMenuItem(
                    label: 'Etichette…',
                    icon: PostinoIcons.tag,
                    onPressed: () => unawaited(openLabelPicker(row, t, returnFocus: focus)),
                  ),
                ],
                child: PostinoLabeledMessageTile(
                  focusNode: focus,
                  sender: t.sender,
                  subject: t.subject,
                  preview: t.preview,
                  time: t.time,
                  unread: t.unread,
                  starred: t.starred,
                  selected: s.openId == t.id,
                  labels: s.chipsInList ? names : const [],
                  semanticLabel: [
                    if (t.unread) 'Non letto',
                    t.sender,
                    t.subject,
                    if (t.starred) 'con Stella',
                    if (names.isNotEmpty) 'Etichette: ${names.join(', ')}',
                    t.time,
                  ].join(', '),
                  onTap: () => s.update(() => s.openId = t.id),
                ),
              );
            },
          ),
      ],
    );
  }
}
