import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/message.dart';
import '../../../i18n/strings.g.dart';
import 'message_list.dart';

/// An Account's inbox, with the Account's own Etichette to open.
class AccountView extends StatefulWidget {
  const AccountView({
    super.key,
    required this.accountId,
    required this.onOpenLabel,
  });
  final String accountId;
  final void Function(String labelId) onOpenLabel;

  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {
  late final labels = streamSignal(
    () => GetIt.I<InboxRepository>().watchLabels(widget.accountId),
  );

  @override
  void dispose() {
    labels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t.postaInArrivo)),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SignalBuilder(
          // One scrolling row: many Etichette never push the messages out.
          builder: (context) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 8,
              children: [
                for (final l in labels.value.value ?? const <Label>[])
                  ActionChip(
                    key: ValueKey('label-${l.id}'),
                    label: Text(l.name),
                    onPressed: () => widget.onOpenLabel(l.id),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: MessageList(
            watch: (r) => r.watchMessages(widget.accountId, inboxLabelId),
          ),
        ),
      ],
    ),
  );
}

/// The messages of one Etichetta of an Account.
class LabelView extends StatelessWidget {
  const LabelView({super.key, required this.accountId, required this.labelId});
  final String accountId;
  final String labelId;

  @override
  Widget build(BuildContext context) => Scaffold(
    // ponytail: titled by id; the name needs the label looked up, with the design pass.
    appBar: AppBar(title: Text(labelId)),
    body: MessageList(watch: (r) => r.watchMessages(accountId, labelId)),
  );
}
