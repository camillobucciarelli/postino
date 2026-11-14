import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/conflict.dart';
import '../../../core/domain/draft_conflict.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'conflict_row.dart';
import 'draft_conflict_row.dart';
import 'row_motion.dart';

/// The open Conflitti, of every Account or only of [accountId]: one [ConflictRow] each, then a [DraftConflictRow] for
/// each Bozza (#149), resolved with a tap.
/// The row leaves the list, the focus goes to the choices of the one now in its place, and the count, a live region,
/// is announced. Routing is the caller's: Esc and the back arrow call [onBack].
/// A resolved row fades and closes (RowMotion and PostinoSizeFade, #283), the last one fades through to the empty
/// state; nothing moves while the lists load.
class const ConflictsScreen({super.key, required final VoidCallback onBack, final String? accountId})
    extends StatefulWidget {
  @override
  State<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState() extends State<ConflictsScreen> with AccountsSignal, TickerProviderStateMixin {
  late final conflicts = streamSignal(() => GetIt.I<InboxRepository>().watchConflicts(accountId: widget.accountId));
  late final drafts = streamSignal(() => GetIt.I<InboxRepository>().watchDraftConflicts(accountId: widget.accountId));
  final _emptyFocus = FocusNode(debugLabel: 'Nessun conflitto');
  final _choices = <String, FocusNode>{};
  late final _motion = RowMotion<(Object, Account)>(this, () => mounted ? setState(() {}) : null, (r) => _key(r.$1));

  /// Every open Conflitto: a [Conflict], or a [DraftConflict].
  List<Object> get _all => [...?conflicts.value.value, ...?drafts.value.value];

  static String _key(Object c) => switch (c) {
    Conflict() => '${c.accountId}/${c.messageId}/${c.local.attribute}',
    DraftConflict() => '${c.accountId}/${c.messageId}/draft',
    _ => throw ArgumentError(c),
  };

  FocusNode _choice(Object c) => _choices.putIfAbsent(_key(c), FocusNode.new);

  /// The Conflitto just resolved and where it sat: once it leaves the list, the focus goes to what took its place.
  Object? _resolved;
  int _at = 0;

  Future<void> _resolve(Object c, {required bool keepMine}) async {
    _at = _all.indexOf(c);
    _resolved = c;
    try {
      await switch (c) {
        DraftConflict() => GetIt.I<MailSync>().resolveDraftConflict(c, keepMine: keepMine),
        _ => GetIt.I<MailSync>().resolveConflict(c as Conflict, keepMine: keepMine),
      };
    } on Object {
      _resolved = null;
      rethrow;
    }
  }

  void _refocus(List<Object> rest) {
    if (_resolved == null || rest.contains(_resolved)) return;
    _resolved = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (rest.isEmpty ? _emptyFocus : _choice(rest[_at.clamp(0, rest.length - 1)])).requestFocus();
    });
  }

  @override
  void dispose() {
    conflicts.dispose();
    drafts.dispose();
    _motion.dispose();
    _emptyFocus.dispose();
    for (final n in _choices.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final t = context.t.conflitti;
      final list = _all;
      _refocus(list);
      final byId = {for (final a in accounts.value.value ?? const <Account>[]) a.id: a};
      final rows = [
        for (final k in list)
          if (byId[switch (k) {
                Conflict(:final accountId) || DraftConflict(:final accountId) => accountId,
                _ => null,
              }]
              case final a?)
            (k, a),
      ];
      final loading = [conflicts.value, drafts.value, accounts.value].any((s) => s.isLoading && !s.hasValue);
      final shown = _motion.update(
        loading ? null : rows,
        enter: PostinoMotion.of(context, PostinoMotion.rowEnter),
        leave: PostinoMotion.of(context, PostinoMotion.swipeDismiss),
      );
      return PostinoDetailPage(
        title: t.title,
        onBack: widget.onBack,
        child: shown == null
            ? const SizedBox.shrink()
            : PostinoFadeThrough(
                transitionKey: shown.isEmpty,
                child: shown.isEmpty ? _empty(context) : _list(context, shown, rows.length),
              ),
      );
    },
  );

  Widget _empty(BuildContext context) => Focus(
    focusNode: _emptyFocus,
    child: PostinoEmptyState(title: context.t.conflitti.emptyTitle, body: context.t.conflitti.emptyBody),
  );

  /// The [shown] rows, the leaving ones among them; [count] the open Conflitti.
  Widget _list(BuildContext context, List<(Object, Account)> shown, int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // The count, announced when it changes.
      Semantics(
        container: true,
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PostinoSpacing.s4,
            PostinoSpacing.s3,
            PostinoSpacing.s4,
            PostinoSpacing.s1,
          ),
          child: Text(
            context.t.conflitti.bannerTitle(n: count),
            style: PostinoText.meta.copyWith(color: context.pc.inkMuted),
          ),
        ),
      ),
      Expanded(
        child: ListView(
          children: [
            for (final (k, a) in shown)
              PostinoSizeFade(
                key: ValueKey(_key(k)),
                visibility: _motion.of(_key(k)),
                leaving: _motion.leaving(_key(k)),
                child: switch (k) {
                  DraftConflict() => DraftConflictRow(
                    conflict: k,
                    account: a,
                    firstChoice: _choice(k),
                    onResolve: ({required keepMine}) => unawaited(_resolve(k, keepMine: keepMine)),
                  ),
                  _ => ConflictRow(
                    conflict: k as Conflict,
                    account: a,
                    firstChoice: _choice(k),
                    onResolve: ({required keepMine}) => unawaited(_resolve(k, keepMine: keepMine)),
                  ),
                },
              ),
          ],
        ),
      ),
    ],
  );
}
