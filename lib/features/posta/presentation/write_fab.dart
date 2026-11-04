import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/message.dart' show newMessageId;
import '../../../core/presentation/accounts_signal.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'posta_shortcuts.dart';

/// The «Scrivi» button over a list, and the `c` shortcut through [cursor]: a new Bozza from [accountId]
/// (the open Account), else the first Account by position. [onWrite] gets the Account and the fresh
/// Message-ID: routing is the caller's. Hidden, and the key idle, without an Account.
class WriteFab extends StatefulWidget {
  const WriteFab({
    super.key,
    this.accountId,
    this.cursor,
    required this.onWrite,
  });
  final String? accountId;
  final ListCursor? cursor;
  final void Function(String accountId, String messageId) onWrite;

  @override
  State<WriteFab> createState() => _WriteFabState();
}

class _WriteFabState extends State<WriteFab> with AccountsSignal {
  List<Account> get _accounts => accounts.value.value ?? const [];

  @override
  void initState() {
    super.initState();
    widget.cursor?.write = _write;
  }

  @override
  void dispose() {
    if (widget.cursor?.write == _write) widget.cursor!.write = null;
    super.dispose();
  }

  void _write() {
    final a =
        _accounts.where((a) => a.id == widget.accountId).firstOrNull ??
        _accounts.firstOrNull;
    if (a != null) widget.onWrite(a.id, newMessageId(a.address));
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => _accounts.isEmpty
        ? const SizedBox.shrink()
        : PostinoFab(
            label: context.t.composizione.write,
            icon: PostinoIcons.pencil,
            onPressed: _write,
          ),
  );
}
