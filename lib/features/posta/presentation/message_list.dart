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
import '../domain/inbox_sections.dart';
import 'act_on_conversation.dart';
import 'conversation_actions.dart';
import 'conversation_row.dart';
import 'conversation_tile.dart';
import 'list_items.dart';
import 'posta_shortcuts.dart';
import 'refresh_mail.dart';
import 'row_motion.dart';
import 'section_heading.dart';

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

  /// The posta in arrivo (#366): Contrassegnate, Da leggere and Letti; «Mostra tutti» calls it with its section.
  final void Function(InboxSection section)? onShowAll,

  /// Only this section of the posta in arrivo, all of it and without heading (the screen of «Mostra tutti»).
  final InboxSection? section,
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

  /// Rows and headings entering and leaving (#282); a row that changes section leaves one and enters the other.
  late final _motion = RowMotion<ListItem>(this, () => mounted ? setState(() {}) : null, itemKey);

  /// The items drawn: the rows of [_list] and the headings, plus the ones on their way out.
  List<ListItem>? _drawn;

  /// The sections of the last list (#366), and the open Conversazione kept in its own (the focus rule).
  InboxSections? _sections;
  HeldConversation? _held;
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

  /// The posta in arrivo (#366): its sections, or one of them.
  bool get _sectioned => widget.onShowAll != null || widget.section != null;

  /// Side by side with the Conversazione: moving opens it (ADR 0014).
  bool get _twoPane => MediaQuery.sizeOf(context).width >= PostinoSize.breakpointListDetail;

  FocusNode _node((String, String) key) => _nodes.putIfAbsent(key, () {
    final node = FocusNode(skipTraversal: true);
    // Focus got there some other way (Tab, a click): the cursor follows.
    node.addListener(() {
      if (node.hasPrimaryFocus && _cursor != key && mounted) {
        setState(() => _cursor = key);
      } else if (node.hasPrimaryFocus && _sectioned && _held?.$1 != key && mounted) {
        // The focus came to the cursor row: its section is held from now (#366), its menu included.
        setState(() {});
      } else if (!node.hasFocus && _held?.$1 == key && widget.selected != key && mounted && _focusOnPage()) {
        // The focus left the row its section was held for (#366) for another control of the page: it goes where its
        // state says now. Not for its menu, which floats over the page and gives the focus back.
        setState(() {});
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

  /// The Conversazione with the focus for the sections (#366): the open one, else the row the keyboard is on.
  /// Its menu, or a dialog opened from it, keeps the row held: the focus is only lent to them.
  (String, String)? _focused() {
    final cursor = _cursor;
    if (widget.selected != null || cursor == null) return widget.selected;
    if (_nodes[cursor]?.hasFocus ?? false) return cursor;
    return _held?.$1 == cursor && _focusOverPage() ? cursor : null;
  }

  /// The focus is in a row's menu or in a dialog over the page (not on another page).
  bool _focusOverPage() {
    final focused = FocusManager.instance.primaryFocus?.context;
    return focused != null &&
        (ModalRoute.of(focused) is PopupRoute || focused.findAncestorStateOfType<PostinoContextMenuState>() != null);
  }

  /// The focus is on a control of the page the list is on, not in a row's menu or a dialog over the page.
  bool _focusOnPage() {
    final focused = FocusManager.instance.primaryFocus?.context;
    return focused != null &&
        ModalRoute.of(focused) == ModalRoute.of(context) &&
        focused.findAncestorStateOfType<PostinoContextMenuState>() == null;
  }

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
    final at = list.indexWhere((i) => i.entry != null && keyOf(i.entry!) == key && !_motion.leaving(itemKey(i)));
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
      _cursor = keyOf(list.first);
      return;
    }
    bool at(InboxEntry e) => keyOf(e) == cursor;
    if (list.any(at)) return;
    // The row still has the focus (it is built until this frame ends): it goes to the row that takes its place,
    // or it would fall to the route's scope, out of the shortcuts. A focus that was elsewhere is not taken.
    final hadFocus = _nodes[cursor]?.hasFocus ?? false;
    final was = _list?.indexWhere(at) ?? -1;
    if (list.isEmpty) {
      _cursor = null;
    } else {
      final e = list[(was < 0 ? 0 : was).clamp(0, list.length - 1)];
      _cursor = keyOf(e);
      // Not under a full-page Conversazione (narrowed in the same frame): there the focus belongs to it.
      if (hadFocus && (_twoPane || widget.selected == null)) _focusSoon();
    }
  }

  /// Moves focus and selection together by [delta] rows; opens the row where selection is opening
  /// (two panes, or a Conversazione already open), else only the focus moves.
  void _move(int delta) {
    final list = _list;
    if (list == null || list.isEmpty) return;
    final from = _cursor == null ? -1 : list.indexWhere((e) => keyOf(e) == _cursor);
    final to = from < 0 ? 0 : (from + delta).clamp(0, list.length - 1);
    final e = list[to];
    final key = keyOf(e);
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
    final at = list.indexWhere((e) => keyOf(e) == key);
    if (at < 0) return null;
    bool conversation(int i) => !list[i].message.conversationId.startsWith('<');
    final after = [for (var i = at + 1; i < list.length; i++) i].where(conversation).firstOrNull;
    final to = after ?? [for (var i = at - 1; i >= 0; i--) i].where(conversation).firstOrNull;
    if (to == null) return null;
    final e = list[to];
    final next = keyOf(e);
    setState(() => _cursor = next);
    _reveal(next, to - at);
    return next;
  }

  /// A shortcut's Azione on the focused row; Archivia and Elimina move the focus on. The open Conversazione's row
  /// goes through it, which moves the selection on or closes it.
  void _actOnRow(PostaAction shortcut) {
    final key = _cursor;
    final e = _list?.where((e) => keyOf(e) == key).firstOrNull;
    // A Bozza or a queued Inviati row (its Conversazione is its Message-ID) is no Conversazione.
    if (key == null || e == null || !_listFocused() || key.$2.startsWith('<')) return;
    if (key == widget.selected && widget.cursor?.act != null) return widget.cursor!.act!(shortcut);
    final action = mailActionFor(shortcut, starred: isStarred(e));
    if (action == null) return;
    unawaited(actOnStoredConversation(context, key.$1, key.$2, action, view: widget.view));
    if (leavesList(action)) _step(key);
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final all = entries.value.value;
      // Read here, not in itemBuilder (which runs at layout, outside the tracking): a change rebuilds the rows.
      final swipeActions = swipes.value.value ?? swipeActionsDefault;
      final sections = _sectioned && all != null
          ? InboxSections.of(all, held: _held = holdFocus(_focused(), _held, _sections))
          : null;
      _sections = sections;
      final items = all == null ? null : listItems(all, sections, only: widget.section);
      // The Conversazioni in the order shown: the cursor and the keys go through them, over the headings.
      final list = items == null ? null : [for (final i in items) ?i.entry];
      _realign(list);
      _list = list;
      final shown = _drawn = _motion.update(
        items,
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
          final item = shown![i];
          final entry = item.entry;
          if (entry == null) return sectionHeading(context, item, motion: _motion, onShowAll: widget.onShowAll);
          final key = keyOf(entry);
          final ik = itemKey(item);
          PostinoMessageTile tile(FocusNode? node, [Map<CustomSemanticsAction, VoidCallback>? semanticActions]) =>
              conversationTile(
                context,
                entry,
                node: node,
                accountLabels: _labelsOf(entry.account.id),
                conflict: inConflict.contains((entry.account.id, entry.message.id)),
                selected: widget.selected == key,
                showAccount: widget.showAccount,
                now: now,
                semanticActions: semanticActions,
                onTap: () {
                  setState(() => _cursor = key);
                  node?.requestFocus();
                  widget.onOpen(key.$1, key.$2);
                },
              );
          // Changing section, its old place fades as a copy: the focus and the actions are on the row it moves to.
          if (_motion.leaving(ik) && list!.any((e) => keyOf(e) == key)) {
            return PostinoSizeFade(
              key: ValueKey(ik),
              visibility: _motion.of(ik),
              leaving: true,
              child: ExcludeFocus(child: tile(null)),
            );
          }
          final node = _node(key)..skipTraversal = key != (_cursor ?? _firstKey(list!));
          return PostinoSizeFade(
            // By Conversazione, not by index: a list that changes under a swipe in progress keeps it with its row.
            key: ValueKey(ik),
            visibility: _motion.of(ik),
            leaving: _motion.leaving(ik),
            child: conversationRow(
              entry,
              node: node,
              keep: key == _cursor,
              swipeActions: swipeActions,
              view: widget.view,
              onOpenAct: widget.selected == key ? widget.cursor?.apply : null,
              tile: ([semanticActions]) => tile(node, semanticActions),
            ),
          );
        },
      );
    },
  );
}

/// The first row, the Tab stop before any focus; none in a list emptied while its last rows leave.
(String, String)? _firstKey(List<InboxEntry> list) => list.isEmpty ? null : keyOf(list.first);
