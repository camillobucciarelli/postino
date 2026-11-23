// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/message.dart' show inboxLabelId;
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/inbox_sections.dart';
import 'conversation_view.dart';
import 'list_items.dart';
import 'message_list.dart';
import 'posta_shortcuts.dart';

/// «Mostra tutti» (#366): every Conversazione of one [section] of the posta in arrivo, of [accountId] or of the
/// Posta unificata (null), with the same focus rule and row actions as the list it is opened from.
/// A Conversazione opens beside the list, or over it on a narrow window, and back returns to the list.
/// Esc, with nothing open, and Indietro leave ([onBack]); [onOpenDraft] opens the composer of a Bozza just saved.
class const InboxSectionScreen({
  super.key,
  required final InboxSection section,
  required final VoidCallback onBack,
  required final void Function(String accountId, String messageId) onOpenDraft,
  final String? accountId,
}) extends StatefulWidget {
  @override
  State<InboxSectionScreen> createState() => _InboxSectionScreenState();
}

class _InboxSectionScreenState() extends State<InboxSectionScreen> with AccountsSignal {
  final _cursor = ListCursor();

  /// (account, conversation) open beside the list.
  (String, String)? _open;

  void _close() => setState(() => _open = null);

  /// The Account's name, or all of them.
  String _scopeName(BuildContext context) {
    final id = widget.accountId;
    if (id == null) return context.t.sezioni.scopeAll;
    return accounts.value.value?.where((a) => a.id == id).firstOrNull?.name ?? '';
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    // The system's Indietro (Android) closes the open Conversazione first, as in the search.
    builder: (context) => BackButtonListener(
      onBackButtonPressed: () async {
        if (_open == null || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
        _close();
        return true;
      },
      child: PostaShortcuts(
        cursor: _cursor,
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onBack},
          // As a PostinoDetailPage: the focus starts in the screen, so Esc reaches it.
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: PostinoListDetailLayout(
                list: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PostinoAppBar(
                      title: sectionTitle(context.t, widget.section),
                      subtitle: _scopeName(context),
                      onBack: widget.onBack,
                    ),
                    Expanded(
                      child: PostinoBelowBar(
                        child: MessageList(
                          watch: (r) {
                            final id = widget.accountId;
                            return id == null ? r.watchUnifiedInbox() : r.watchMessages(id, inboxLabelId);
                          },
                          section: widget.section,
                          showAccount: widget.accountId == null,
                          selected: _open,
                          cursor: _cursor,
                          onOpen: (a, c) => setState(() => _open = (a, c)),
                        ),
                      ),
                    ),
                  ],
                ),
                detail: _open == null
                    ? null
                    : ConversationView(
                        key: ValueKey('section-${_open!.$1}/${_open!.$2}'),
                        accountId: _open!.$1,
                        conversationId: _open!.$2,
                        onBack: _close,
                        onOpenDraft: (id) => widget.onOpenDraft(_open!.$1, id),
                        cursor: _cursor,
                      ),
                detailKey: _open,
                empty: PostinoEmptyState(
                  title: context.t.conversazione.selectTitle,
                  body: context.t.conversazione.selectBody,
                  icon: PostinoIcons.inbox,
                ),
                onClose: _close,
                resizeLabel: context.t.listWidth.label,
                resizeValueLabel: (w) => context.t.listWidth.value(px: w.round()),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
