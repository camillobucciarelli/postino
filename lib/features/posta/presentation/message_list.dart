import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/platform_services.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'conversation_labels.dart';
import 'message_time.dart';
import 'posta_shortcuts.dart';

/// List of Conversazioni (Posta unificata, an Account's inbox, an Etichetta); reads only from the local database
/// through [InboxRepository]. Pull-to-refresh asks for a sync; the rows update when it writes the database.
/// Routing is the caller's: a tap calls [onOpen], and [selected] is the Conversazione open beside the list.
class const MessageList({
  super.key,

  /// Which messages to show, e.g. `repo.watchUnifiedInbox`.
  required final Stream<List<InboxEntry>> Function(InboxRepository repo) watch,
  required final void Function(String accountId, String conversationId) onOpen,

  /// Marks each row with its Account (bar and badge): only where Accounts mix.
  final bool showAccount = false,

  /// (accountId, conversationId).
  final (String, String)? selected,

  /// Plugs the list into the keyboard shortcuts ([PostaShortcuts]).
  final ListCursor? cursor,

  /// What an empty list says (the Bozze have their own); default: the inbox's.
  final String? emptyTitle,
  final String? emptyBody,
}) extends StatefulWidget {
  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState() extends State<MessageList> {
  late final entries = streamSignal(() => widget.watch(GetIt.I<InboxRepository>()));
  final _scroll = ScrollController();

  /// One focus per row; only the cursor row is a Tab stop, so the list is one stop.
  // ponytail: nodes of rows that left the list live until dispose; prune if lists churn a lot.
  final _nodes = <(String, String), FocusNode>{};

  /// The row with the focus (or that had it last): the open one, or the one the arrows reached.
  (String, String)? _cursor;
  List<InboxEntry>? _list;
  bool? _wasTwoPane;

  /// The Etichette of each Account in the list, to name the ids of the rows; subscribed when a row first needs them.
  final _labels = <String, List<Label>>{};
  final _labelSubs = <String, StreamSubscription<List<Label>>>{};

  List<Label> _labelsOf(String accountId) {
    _labelSubs.putIfAbsent(
      accountId,
      () => GetIt.I<InboxRepository>()
          .watchLabels(accountId)
          .listen((l) => mounted ? setState(() => _labels[accountId] = l) : null),
    );
    return _labels[accountId] ?? const [];
  }

  /// Side by side with the Conversazione: moving opens it (ADR 0014).
  bool get _twoPane => MediaQuery.sizeOf(context).width >= PostinoSize.breakpointListDetail;

  FocusNode _node((String, String) key) => _nodes.putIfAbsent(key, () {
    final node = FocusNode(skipTraversal: true);
    // Focus got there some other way (Tab, a click): the cursor follows.
    node.addListener(() {
      if (node.hasPrimaryFocus && _cursor != key && mounted) {
        setState(() => _cursor = key);
      }
    });
    return node;
  });

  @override
  void initState() {
    super.initState();
    _cursor = widget.selected;
    widget.cursor
      ?..move = _move
      ..listFocused = _listFocused;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final two = _twoPane;
    // Widened with a Conversazione open: the focus goes to its row; the Conversazione stays.
    if (_wasTwoPane == false && two && widget.selected != null) _focusSoon();
    _wasTwoPane = two;
  }

  @override
  void didUpdateWidget(MessageList old) {
    super.didUpdateWidget(old);
    final open = widget.selected;
    if (open != null) _cursor = open;
    // The Conversazione closed: the focus returns to the row just closed.
    if (open == null && old.selected != null) _focusSoon();
  }

  @override
  void dispose() {
    final cursor = widget.cursor;
    if (cursor?.move == _move) {
      cursor!
        ..move = null
        ..listFocused = null;
    }
    for (final n in _nodes.values) {
      n.dispose();
    }
    for (final s in _labelSubs.values) {
      unawaited(s.cancel());
    }
    _scroll.dispose();
    entries.dispose();
    super.dispose();
  }

  /// Focus on the list, and the list is in front (not under a full-page Conversazione).
  bool _listFocused() => _nodes.values.any((n) => n.hasFocus) && (_twoPane || widget.selected == null);

  void _focusSoon() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _cursor != null) _reveal(_cursor!, 0);
  });

  /// Focus on [key]'s row and scroll it into view; a row not built yet is reached by jumping near it first.
  void _reveal((String, String) key, int delta, {int tries = 3}) {
    final node = _node(key);
    // A row that scrolled away is detached from the focus tree (its context is stale).
    if (node.enclosingScope != null) {
      FocusTraversalPolicy.defaultTraversalRequestFocusCallback(
        node,
        alignmentPolicy: delta >= 0
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
      return;
    }
    final list = _list;
    if (tries == 0 || list == null || !_scroll.hasClients) return;
    final at = list.indexWhere((e) => (e.account.id, e.message.conversationId) == key);
    if (at < 0) return;
    final p = _scroll.position;
    final rowExtent = (p.maxScrollExtent + p.viewportDimension) / list.length;
    _scroll.jumpTo((at * rowExtent).clamp(0, p.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reveal(key, delta, tries: tries - 1);
    });
  }

  /// The list changed: a cursor row that is gone (archived elsewhere) moves to the row now at its
  /// place, or the last one; an empty list has no cursor.
  void _realign(List<InboxEntry>? list) {
    final cursor = _cursor;
    if (list == null || list.isEmpty && cursor == null) return;
    // No row focused yet: the first is the Tab stop, so it is the cursor (and stays built).
    if (cursor == null) {
      _cursor = (list.first.account.id, list.first.message.conversationId);
      return;
    }
    bool at(InboxEntry e) => (e.account.id, e.message.conversationId) == cursor;
    if (list.any(at)) return;
    final was = _list?.indexWhere(at) ?? -1;
    if (list.isEmpty) {
      _cursor = null;
    } else {
      final e = list[(was < 0 ? 0 : was).clamp(0, list.length - 1)];
      _cursor = (e.account.id, e.message.conversationId);
    }
  }

  /// Moves focus and selection together by [delta] rows; opens the row where selection is opening
  /// (two panes, or a Conversazione already open), else only the focus moves.
  void _move(int delta) {
    final list = _list;
    if (list == null || list.isEmpty) return;
    final from = _cursor == null ? -1 : list.indexWhere((e) => (e.account.id, e.message.conversationId) == _cursor);
    final to = from < 0 ? 0 : (from + delta).clamp(0, list.length - 1);
    final e = list[to];
    final key = (e.account.id, e.message.conversationId);
    // At the edge: nothing moves, and the focus stays where it is (maybe in the Conversazione).
    if (key == _cursor) return;
    setState(() => _cursor = key);
    _reveal(key, delta);
    if ((_twoPane || widget.selected != null) && key != widget.selected) {
      widget.onOpen(key.$1, key.$2);
    }
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final list = entries.value.value;
      _realign(list);
      _list = list;
      final t = context.t.list;
      final now = GetIt.I<Clock>().now();
      final locale = Localizations.localeOf(context).languageCode;
      return PostinoMessageList(
        controller: _scroll,
        loading: list == null,
        itemCount: list?.length ?? 0,
        onRefresh: GetIt.I<MailSync>().syncAll,
        loadingLabel: t.loading,
        emptyTitle: widget.emptyTitle ?? t.emptyTitle,
        emptyBody: widget.emptyBody ?? t.emptyBody,
        itemBuilder: (context, i) {
          final InboxEntry(message: m, account: a, :count, :unread, :status) = list![i];
          final labels = [
            for (final l in _labelsOf(a.id))
              if (l.kind == LabelKind.etichetta && m.labelIds.contains(l.id)) l.name,
          ];
          final time = messageTime(m.date, now, locale, t.yesterday);
          final key = (a.id, m.conversationId);
          final node = _node(key)..skipTraversal = key != (_cursor ?? _firstKey(list));
          final tile = PostinoMessageTile(
            key: ValueKey('row-${a.id}-${m.id}'),
            focusNode: node,
            sender: m.fromName ?? m.from,
            subject: m.subject,
            preview: m.snippet,
            time: time,
            unread: unread,
            starred: m.isStarred,
            count: count,
            labels: labels,
            selected: widget.selected == key,
            onTap: () {
              setState(() => _cursor = key);
              node.requestFocus();
              widget.onOpen(a.id, m.conversationId);
            },
            account: widget.showAccount ? (color: PostinoAccountColor.values[a.color], initial: a.initial) : null,
            semanticLabel: [
              if (unread) t.unread,
              m.fromName ?? m.from,
              m.subject,
              if (count > 1) t.messages(n: count),
              ?status,
              if (m.isStarred) t.starred,
              if (widget.showAccount) t.account(name: a.name),
              ...labels,
              time,
            ].join(', '),
          );
          return _KeepAlive(
            keep: key == _cursor,
            // A Bozza or a queued Inviati row (its Conversazione is its Message-ID) is no Conversazione: no picker.
            child: m.conversationId.startsWith('<')
                ? tile
                : Builder(
                    builder: (row) => PostinoContextMenu(
                      items: [
                        PostinoMenuItem(
                          key: ValueKey('row-labels-${a.id}-${m.id}'),
                          label: context.t.selettoreEtichette.menuItem,
                          onPressed: () => unawaited(
                            openLabelPicker(row, accountId: a.id, conversationId: m.conversationId, returnFocus: node),
                          ),
                        ),
                      ],
                      child: tile,
                    ),
                  ),
          );
        },
      );
    },
  );
}

(String, String) _firstKey(List<InboxEntry> list) => (list.first.account.id, list.first.message.conversationId);

/// Keeps the cursor row built when it scrolls out of sight, so Tab still finds it.
class const _KeepAlive({required final bool keep, required final Widget child}) extends StatefulWidget {
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState() extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keep;

  @override
  void didUpdateWidget(_KeepAlive old) {
    super.didUpdateWidget(old);
    if (old.keep != widget.keep) updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
