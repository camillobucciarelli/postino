import 'package:flutter/widgets.dart';

import '../../../core/domain/account.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// What the chooser answers: the id of the Account, or null for «Nessuno». Dismissing it answers nothing.
typedef SyncAccountChoice = ({String? accountId});

/// «Sincronizza su…»: «Nessuno» and one row per Gmail Account, the [current] one ticked. Picking a row closes it
/// with the choice; Esc or «Annulla» close it with nothing. The ticked row has the focus when it opens.
Future<SyncAccountChoice?> showSyncAccountChooser(BuildContext context, List<Account> accounts, String? current) =>
    showPostinoDialog<SyncAccountChoice>(
      context,
      title: context.t.impostazioni.syncChooserTitle,
      child: _Chooser(accounts: accounts, current: current),
    );

class const _Chooser({required final List<Account> accounts, required final String? current}) extends StatefulWidget {
  @override
  State<_Chooser> createState() => _ChooserState();
}

class _ChooserState() extends State<_Chooser> {
  /// The ticked row: the keyboard lands on it.
  final _first = FocusNode(debugLabel: 'Sincronizza su');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _first.requestFocus());
  }

  @override
  void dispose() {
    _first.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.impostazioni;
    final current = widget.current;
    // Nessuno is ticked also when the remembered Account is no longer there.
    final known = widget.accounts.any((a) => a.id == current);
    void pick(String? id) => Navigator.of(context).pop<SyncAccountChoice>((accountId: id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PostinoSpacing.s4,
      children: [
        Column(
          children: [
            PostinoCheckboxTile(
              key: const ValueKey('sync-none'),
              label: t.syncNone,
              value: !known,
              focusNode: !known ? _first : null,
              onChanged: (_) => pick(null),
            ),
            for (final a in widget.accounts)
              PostinoCheckboxTile(
                key: ValueKey('sync-${a.id}'),
                label: a.name,
                value: a.id == current,
                focusNode: a.id == current ? _first : null,
                onChanged: (_) => pick(a.id),
              ),
          ],
        ),
        PostinoDialogActions(
          children: [
            PostinoButton(
              label: t.syncCancel,
              variant: PostinoButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}
