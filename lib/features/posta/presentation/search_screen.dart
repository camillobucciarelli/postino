import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/provider_search_use_case.dart';
import '../../../core/domain/search_query.dart';
import '../../../core/domain/search_query_parser.dart';
import '../../../core/domain/search_repository.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'conversation_view.dart';
import 'message_list.dart';
import 'posta_shortcuts.dart';
import 'provider_search.dart';
import 'provider_search_status.dart';

/// The search of the Posta (#205): one field, the results below it as the Conversazioni of any list, updated while
/// the user types; Invio searches the Providers too (#207), whose finds join the results. [accountId] narrows it to
/// that Account (the view it was opened from); null searches all.
/// A result opens beside the list, or over it on a narrow window, and back returns to the results.
/// `/` puts the focus in the field, Esc clears it and then leaves ([onBack]), Freccia giù goes to the results.
/// Routing is the caller's: [onBack], and [onOpenDraft] for the composer of a Bozza a Rispondi just saved.
class const SearchScreen({
  super.key,
  required final VoidCallback onBack,
  required final void Function(String accountId, String messageId) onOpenDraft,
  final String? accountId,
}) extends StatefulWidget {
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState() extends State<SearchScreen> with AccountsSignal {
  final _text = TextEditingController();
  final _field = FocusNode(debugLabel: 'Cerca nella posta');
  final _cursor = ListCursor();
  Timer? _debounce;
  final _providers = ProviderSearch(GetIt.I<ProviderSearchUseCase>());

  /// What the results show; the list is rebuilt for each new one.
  SearchQuery _query = const SearchQuery();

  /// How many Conversazioni the results hold, null until the current query answers (and with no query).
  int? _count;

  /// (account, conversation) open beside the results.
  (String, String)? _open;

  @override
  void initState() {
    super.initState();
    _cursor.search = _focusField;
  }

  /// `/`: the focus goes to the field. On a narrow window an open Conversazione covers it (the list is kept under
  /// it, hidden): it closes first, so the field is on screen when it takes the focus.
  void _focusField() {
    if (_open != null && MediaQuery.sizeOf(context).width < PostinoSize.breakpointListDetail) {
      setState(() => _open = null);
      _focusWhenShown();
    } else {
      _field.requestFocus();
    }
  }

  /// Two frames on: the list is back on stage, and has returned its own focus to the row just closed, so the field
  /// has the last word.
  void _focusWhenShown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => mounted ? _field.requestFocus() : null)
      ..scheduleFrame();
  });

  @override
  void dispose() {
    _debounce?.cancel();
    _providers.dispose();
    _text.dispose();
    _field.dispose();
    super.dispose();
  }

  void _changed(String text) {
    _debounce?.cancel();
    // A short pause: results while typing, not a query per key.
    _debounce = Timer(const Duration(milliseconds: 150), () => _apply(text));
  }

  void _apply(String text) {
    if (!mounted) return;
    final query = parseSearchQuery(text);
    final scope = widget.accountId;
    final scoped = scope == null ? query : query.inAccounts({scope});
    if (scoped == _query) return;
    // What the Providers found was for the old text.
    _providers.clear();
    setState(() {
      _query = scoped;
      _count = null;
    });
  }

  /// Invio: the search goes to the Providers as well (#207), the only time it does.
  void _submit(String text) {
    _debounce?.cancel();
    _apply(text);
    // ponytail: the query as the local search reads it; the operators of #206 are translated by each adapter.
    if (!_query.isEmpty) unawaited(_providers.start(_query));
  }

  /// Esc: first empties the field, then leaves the search.
  void _escape() {
    if (_text.text.isEmpty) return widget.onBack();
    _text.clear();
    _debounce?.cancel();
    _apply('');
  }

  Widget _results(BuildContext context) {
    final t = context.t.cerca;
    final searching = !_query.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PostinoAppBar(title: t.title, subtitle: _scopeName(context), onBack: widget.onBack),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PostinoSpacing.s4,
            PostinoSpacing.s2,
            PostinoSpacing.s4,
            PostinoSpacing.s2,
          ),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): _escape,
              const SingleActivator(LogicalKeyboardKey.arrowDown): () => _cursor.focusRow?.call(),
            },
            child: PostinoTextField(
              label: t.field,
              icon: PostinoIcons.search,
              controller: _text,
              focusNode: _field,
              autofocus: true,
              onChanged: _changed,
              onSubmitted: _submit,
              textInputAction: TextInputAction.search,
            ),
          ),
        ),
        ProviderSearchStatus(search: _providers),
        // The number of results (or none), announced when it changes; it takes no room.
        Semantics(
          liveRegion: true,
          container: true,
          label: switch (_count) {
            null => '',
            0 => t.emptyTitle,
            final n => t.results(n: n),
          },
          child: const SizedBox(height: 1),
        ),
        Expanded(
          child: MessageList(
            // A new query is a new list: its stream starts over.
            key: ValueKey(_query),
            watch: (_) => GetIt.I<SearchRepository>().watchLocal(_query, found: _providers.watchFound()),
            showAccount: widget.accountId == null,
            selected: _open,
            cursor: _cursor,
            onOpen: (a, c) => setState(() => _open = (a, c)),
            onCount: (n) => setState(() => _count = searching ? n : null),
            emptyIcon: PostinoIcons.search,
            emptyTitle: searching ? t.emptyTitle : t.idleTitle,
            emptyBody: searching ? t.emptyBody : t.idleBody,
          ),
        ),
      ],
    );
  }

  /// The Account searched, or all of them.
  String _scopeName(BuildContext context) {
    final id = widget.accountId;
    if (id == null) return context.t.cerca.scopeAll;
    return accounts.value.value?.where((a) => a.id == id).firstOrNull?.name ?? '';
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    // The system's Indietro (Android) closes the open Conversazione first, like its own Indietro: the detail is
    // drawn here, not pushed, so there is no page to pop; the results stay.
    builder: (context) => BackButtonListener(
      onBackButtonPressed: () async {
        if (_open == null || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
        setState(() => _open = null);
        return true;
      },
      child: PostaShortcuts(
        cursor: _cursor,
        // From a result with nothing open, Esc goes back to the field.
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): _field.requestFocus},
          child: Scaffold(
            body: PostinoListDetailLayout(
              list: _results(context),
              detail: _open == null
                  ? null
                  : ConversationView(
                      key: ValueKey('search-${_open!.$1}/${_open!.$2}'),
                      accountId: _open!.$1,
                      conversationId: _open!.$2,
                      onBack: () => setState(() => _open = null),
                      onOpenDraft: (id) => widget.onOpenDraft(_open!.$1, id),
                      cursor: _cursor,
                    ),
              detailKey: _open,
              empty: PostinoEmptyState(
                title: context.t.conversazione.selectTitle,
                body: context.t.conversazione.selectBody,
                icon: PostinoIcons.inbox,
              ),
              onClose: () => setState(() => _open = null),
              resizeLabel: context.t.listWidth.label,
              resizeValueLabel: (w) => context.t.listWidth.value(px: w.round()),
            ),
          ),
        ),
      ),
    ),
  );
}
