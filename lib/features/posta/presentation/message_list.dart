import 'dart:async';

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/platform_services.dart';
import '../../../core/domain/swipe_actions.dart';
import '../../../core/domain/swipe_actions_repository.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'act_on_conversation.dart';
import 'conversation_actions.dart';
import 'message_time.dart';
import 'posta_shortcuts.dart';
import 'refresh_mail.dart';
import 'row_keep_alive.dart';
import 'row_menu.dart';
import 'row_motion.dart';
import 'row_swipe.dart';

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

  /// An icon for the empty state; default: the inbox's.
  final PostinoIconData emptyIcon = PostinoIcons.check,

  /// Called with the number of rows each time it changes (the search announces it); never during a build.
  final ValueChanged<int>? onCount,

  /// The Etichetta of this view: the Azioni and the Etichette of a row reach only the messages it shows.
  final String view = inboxLabelId,
}) extends StatefulWidget {
  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState() extends State<MessageList> with TickerProviderStateMixin {
  late final entries = streamSignal(() => widget.watch(GetIt.I<InboxRepository>()));
  // ponytail: a row is flagged when its latest message is in Conflitto; a Conflitto on an older one shows in the Conversazione.
  late final conflicts = streamSignal(
    () => GetIt.I<InboxRepository>().watchConflicts().map((l) => {for (final c in l) (c.accountId, c.messageId)}),
  );
  late final swipes = streamSignal(() => GetIt.I<SwipeActionsRepository>().watch());
  final _scroll = ScrollController();

  /// One focus per row; only the cursor row is a Tab stop, so the list is one stop.
  // ponytail: nodes of rows that left the list live until dispose; prune if lists churn a lot.
  final _nodes = <(String, String), FocusNode>{};

  /// The row with the focus (or that had it last): the open one, or the one the arrows reached.
  (String, String)? _cursor;
  List<InboxEntry>? _list;

  /// Rows entering and leaving (#282).
  late final _motion = RowMotion<InboxEntry>(
    this,
    () => mounted ? setState(() {}) : null,
    (e) => (e.account.id, e.message.conversationId),
  );

  /// The rows drawn: [_list] plus the ones on their way out.
  List<InboxEntry>? _drawn;
  bool? _wasTwoPane;
  int? _counted;

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
      ..listFocused = _listFocused
      ..leave = _leave
      ..focusRow = _focusCursorRow
      ..actOnRow = _actOnRow;
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
        ..listFocused = null
        ..leave = null
        ..focusRow = null
        ..actOnRow = null;
    }
    for (final n in _nodes.values) {
      n.dispose();
    }
    _motion.dispose();
    for (final s in _labelSubs.values) {
      unawaited(s.cancel());
    }
    _scroll.dispose();
    entries.dispose();
    conflicts.dispose();
    swipes.dispose();
    super.dispose();
  }

  /// Focus on the list, and the list is in front (not under a full-page Conversazione).
  bool _listFocused() => _nodes.values.any((n) => n.hasFocus) && (_twoPane || widget.selected == null);

  /// The focus goes to the cursor row (the first one in a list nobody has moved in).
  void _focusCursorRow() {
    if (_cursor != null) _reveal(_cursor!, 0);
  }

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
    // Where the row is drawn, rows on their way out included (a mass removal leaves them above it for a while).
    final list = _drawn;
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
    // The row still has the focus (it is built until this frame ends): it goes to the row that takes its place,
    // or it would fall to the route's scope, out of the shortcuts. A focus that was elsewhere is not taken.
    final hadFocus = _nodes[cursor]?.hasFocus ?? false;
    final was = _list?.indexWhere(at) ?? -1;
    if (list.isEmpty) {
      _cursor = null;
    } else {
      final e = list[(was < 0 ? 0 : was).clamp(0, list.length - 1)];
      _cursor = (e.account.id, e.message.conversationId);
      // Not under a full-page Conversazione (narrowed in the same frame): there the focus belongs to it.
      if (hadFocus && (_twoPane || widget.selected == null)) _focusSoon();
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

  /// The open Conversazione [key] leaves the list (Archivia, Elimina): the next row opens, else the previous,
  /// with the focus; false when there is none, or [key] is not here.
  bool _leave((String, String) key) {
    final next = _step(key);
    if (next != null) widget.onOpen(next.$1, next.$2);
    return next != null;
  }

  /// Cursor and focus from the row [key] to the next Conversazione, else the previous; null when there is none.
  /// A queued Inviati row (its Conversazione is its Message-ID) is skipped: opening it cancels the send.
  (String, String)? _step((String, String) key) {
    final list = _list ?? const <InboxEntry>[];
    final at = list.indexWhere((e) => (e.account.id, e.message.conversationId) == key);
    if (at < 0) return null;
    bool conversation(int i) => !list[i].message.conversationId.startsWith('<');
    final after = [for (var i = at + 1; i < list.length; i++) i].where(conversation).firstOrNull;
    final to = after ?? [for (var i = at - 1; i >= 0; i--) i].where(conversation).firstOrNull;
    if (to == null) return null;
    final e = list[to];
    final next = (e.account.id, e.message.conversationId);
    setState(() => _cursor = next);
    _reveal(next, to - at);
    return next;
  }

  /// A shortcut's Azione on the focused row; Archivia and Elimina move the focus on. The open Conversazione's row
  /// goes through it, which moves the selection on or closes it.
  void _actOnRow(PostaAction shortcut) {
    final key = _cursor;
    final e = _list?.where((e) => (e.account.id, e.message.conversationId) == key).firstOrNull;
    // A Bozza or a queued Inviati row (its Conversazione is its Message-ID) is no Conversazione.
    if (key == null || e == null || !_listFocused() || key.$2.startsWith('<')) return;
    if (key == widget.selected && widget.cursor?.act != null) return widget.cursor!.act!(shortcut);
    final action = mailActionFor(shortcut, starred: _starred(e));
    if (action == null) return;
    unawaited(actOnStoredConversation(context, key.$1, key.$2, action, view: widget.view));
    if (leavesList(action)) _step(key);
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final list = entries.value.value;
      // Read here, not in itemBuilder (which runs at layout, outside the tracking): a change rebuilds the rows.
      final swipeActions = swipes.value.value ?? swipeActionsDefault;
      _realign(list);
      _list = list;
      final shown = _drawn = _motion.update(
        list,
        enter: PostinoMotion.of(context, PostinoMotion.rowEnter),
        leave: PostinoMotion.of(context, PostinoMotion.swipeDismiss),
      );
      if (list != null && list.length != _counted) {
        _counted = list.length;
        WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? widget.onCount?.call(list.length) : null);
      }
      final t = context.t.list;
      final now = GetIt.I<Clock>().now();
      final inConflict = conflicts.value.value ?? const <(String, String)>{};
      final locale = Localizations.localeOf(context).languageCode;
      return PostinoMessageList(
        controller: _scroll,
        loading: list == null,
        itemCount: shown?.length ?? 0,
        onRefresh: () => refreshMail(context, pull: true),
        loadingLabel: t.loading,
        emptyTitle: widget.emptyTitle ?? t.emptyTitle,
        emptyBody: widget.emptyBody ?? t.emptyBody,
        emptyIcon: widget.emptyIcon,
        itemBuilder: (context, i) {
          final entry = shown![i];
          final InboxEntry(message: m, account: a, :count, :unread, :status) = entry;
          final labels = [
            for (final l in _labelsOf(a.id))
              if (l.kind == LabelKind.etichetta && m.labelIds.contains(l.id)) l.name,
          ];
          final time = messageTime(m.date, now, locale, t.yesterday);
          final key = (a.id, m.conversationId);
          final conflict = inConflict.contains((a.id, m.id));
          final node = _node(key)..skipTraversal = key != (_cursor ?? _firstKey(list!));
          PostinoMessageTile tileWith([Map<CustomSemanticsAction, VoidCallback>? semanticActions]) =>
              PostinoMessageTile(
                key: ValueKey('row-${a.id}-${m.id}'),
                focusNode: node,
                customSemanticsActions: semanticActions,
                sender: m.fromName ?? m.from,
                subject: m.subject,
                preview: m.snippet,
                time: time,
                unread: unread,
                starred: m.isStarred,
                count: count,
                labels: labels,
                conflict: conflict,
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
                  if (m.snippet.isNotEmpty) m.snippet,
                  ?status,
                  if (conflict) context.t.conflitti.sign,
                  if (m.isStarred) t.starred,
                  if (widget.showAccount) t.account(name: a.name),
                  ...labels,
                  time,
                ].join(', '),
              );
          return PostinoSizeFade(
            // By Conversazione, not by index: a list that changes under a swipe in progress keeps it with its row.
            key: ValueKey(key),
            visibility: _motion.of(key),
            leaving: _motion.leaving(key),
            child: RowKeepAlive(
              keep: key == _cursor,
              // A Bozza or a queued Inviati row (its Conversazione is its Message-ID) is no Conversazione: no picker.
              child: m.conversationId.startsWith('<')
                  ? tileWith()
                  : RowSwipe(
                      accountId: a.id,
                      conversationId: m.conversationId,
                      labelsAreFolders: a.provider.labelsAreFolders,
                      read: !unread,
                      starred: _starred(entry),
                      focusNode: node,
                      actions: swipeActions,
                      onOpenAct: widget.selected == key ? widget.cursor?.apply : null,
                      view: widget.view,
                      builder: (semanticActions) => RowMenu(
                        accountId: a.id,
                        messageId: m.id,
                        conversationId: m.conversationId,
                        focusNode: node,
                        labelsAreFolders: a.provider.labelsAreFolders,
                        read: !unread,
                        starred: _starred(entry),
                        onOpenAct: widget.selected == key ? widget.cursor?.apply : null,
                        view: widget.view,
                        child: tileWith(semanticActions),
                      ),
                    ),
            ),
          );
        },
      );
    },
  );
}

/// A message of the Conversazione has the Stella: the row's labels are those of all of them.
bool _starred(InboxEntry e) => e.message.labelIds.contains(starredLabelId);

/// The first row, the Tab stop before any focus; none in a list emptied while its last rows leave.
(String, String)? _firstKey(List<InboxEntry> list) =>
    list.isEmpty ? null : (list.first.account.id, list.first.message.conversationId);
