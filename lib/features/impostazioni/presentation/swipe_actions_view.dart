import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/swipe_actions.dart';
import '../../../core/domain/swipe_actions_repository.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'escape_to_go_back.dart';

/// Impostazioni › Azioni per scorrimento (#147): the Azione of a swipe to the left and of one to the right, for every
/// Account. Esc and the back arrow call [onBack]; routing is the caller's.
class const SwipeActionsView({super.key, required final VoidCallback onBack}) extends StatefulWidget {
  @override
  State<SwipeActionsView> createState() => _SwipeActionsViewState();
}

class _SwipeActionsViewState() extends State<SwipeActionsView> {
  late final _actions = streamSignal(() => GetIt.I<SwipeActionsRepository>().watch());

  @override
  void dispose() {
    _actions.dispose();
    super.dispose();
  }

  String _label(BuildContext context, SwipeAction a) => switch (a) {
    SwipeAction.archive => context.t.azioni.archive,
    SwipeAction.markRead => context.t.scorrimento.markRead,
    SwipeAction.star => context.t.scorrimento.star,
    SwipeAction.delete => context.t.azioni.delete,
    SwipeAction.applyLabel => context.t.azioni.applyLabel,
  };

  Widget _section(BuildContext context, SwipeDirection direction, SwipeAction chosen) => PostinoSettingsSection(
    title: direction == SwipeDirection.left ? context.t.scorrimento.left : context.t.scorrimento.right,
    children: [
      for (final a in SwipeAction.values)
        PostinoChoiceRow(
          key: ValueKey('swipe-${direction.name}-${a.name}'),
          label: _label(context, a),
          selected: a == chosen,
          onSelected: () => unawaited(GetIt.I<SwipeActionsRepository>().set(direction, a)),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => EscapeToGoBack(
    onBack: widget.onBack,
    child: SignalBuilder(
      builder: (context) {
        final chosen = _actions.value.value ?? swipeActionsDefault;
        return PostinoSettingsPage(
          title: context.t.scorrimento.title,
          onBack: widget.onBack,
          intro: context.t.scorrimento.intro,
          sections: [
            _section(context, SwipeDirection.left, chosen.left),
            _section(context, SwipeDirection.right, chosen.right),
          ],
        );
      },
    ),
  );
}
