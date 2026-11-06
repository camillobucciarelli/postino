import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/conflict.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'conflict_row.dart';

/// The open Conflitti, of every Account or only of [accountId]: one [ConflictRow] each, resolved with a tap.
/// The row leaves the list, the focus goes to the choices of the one now in its place, and the count, a live region,
/// is announced. Routing is the caller's: Esc and the back arrow call [onBack].
class const ConflictsScreen({super.key, required final VoidCallback onBack, final String? accountId})
    extends StatefulWidget {
  @override
  State<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState() extends State<ConflictsScreen> with AccountsSignal {
  late final conflicts = streamSignal(() => GetIt.I<InboxRepository>().watchConflicts(accountId: widget.accountId));
  final _emptyFocus = FocusNode(debugLabel: 'Nessun conflitto');
  final _choices = <(String, String, String), FocusNode>{};

  FocusNode _choice(Conflict c) => _choices.putIfAbsent((c.accountId, c.messageId, c.local.attribute), FocusNode.new);

  /// The Conflitto just resolved and where it sat: once it leaves the list, the focus goes to what took its place.
  Conflict? _resolved;
  int _at = 0;

  Future<void> _resolve(Conflict c, {required bool keepMine}) async {
    _at = (conflicts.value.value ?? const <Conflict>[]).indexOf(c);
    _resolved = c;
    await GetIt.I<MailSync>().resolveConflict(c, keepMine: keepMine);
  }

  void _refocus(List<Conflict> rest) {
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
      final c = context.pc;
      final list = conflicts.value.value ?? const <Conflict>[];
      _refocus(list);
      final byId = {for (final a in accounts.value.value ?? const <Account>[]) a.id: a};
      final rows = [
        for (final k in list)
          if (byId[k.accountId] case final a?) (k, a),
      ];
      return PostinoDetailPage(
        title: t.title,
        onBack: widget.onBack,
        child: rows.isEmpty
            ? Focus(
                focusNode: _emptyFocus,
                child: PostinoEmptyState(title: t.emptyTitle, body: t.emptyBody),
              )
            : Column(
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
                        t.bannerTitle(n: rows.length),
                        style: PostinoText.meta.copyWith(color: c.inkMuted),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final (k, a) in rows)
                          ConflictRow(
                            key: ValueKey('${k.accountId}/${k.messageId}/${k.local.attribute}'),
                            conflict: k,
                            account: a,
                            firstChoice: _choice(k),
                            onResolve: ({required keepMine}) => unawaited(_resolve(k, keepMine: keepMine)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      );
    },
  );
}
