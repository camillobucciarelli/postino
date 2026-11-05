import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/label_name.dart';
import '../../../core/domain/mail_notification.dart' show ConversationKey;
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/result.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/conversation_label_intents.dart';
import 'conversation_labels.dart';

/// The content of the picker of the Etichette of a Conversazione, read from the database: the user Etichette of
/// the Account, ticked when on at least one of its messages. A tick applies at once to every message; a new name
/// is created on the Provider and put on them. Removals show their snackbar under [snackbarContext].
class const LabelPickerSheet({
  super.key,
  required final String accountId,
  required final String conversationId,
  required final BuildContext snackbarContext,
}) extends StatefulWidget {
  @override
  State<LabelPickerSheet> createState() => _LabelPickerSheetState();
}

class _LabelPickerSheetState() extends State<LabelPickerSheet> {
  final _subs = <StreamSubscription<Object?>>[];
  List<Message> _messages = const [];
  List<Label> _labels = const [];

  late final ConversationKey _key = (accountId: widget.accountId, conversationId: widget.conversationId);
  final _intents = GetIt.I<ConversationLabelIntents>();

  @override
  void initState() {
    super.initState();
    final repo = GetIt.I<InboxRepository>();
    // The whole Conversazione is brought here: from the list it may never have been opened, and the sync window
    // leaves its older messages out. The ticks taken meanwhile reach them when it ends, the picker closed or not.
    unawaited(
      _intents.fetch(_key, () => GetIt.I<MailSync>().completeConversation(widget.accountId, widget.conversationId)),
    );
    _subs
      ..add(
        repo
            .watchConversation(widget.accountId, widget.conversationId)
            .listen((c) => setState(() => _messages = [for (final m in c) m.message])),
      )
      ..add(repo.watchLabels(widget.accountId).listen((l) => setState(() => _labels = l)));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  Set<String> get _selected => {for (final m in _messages) ...m.labelIds};

  void _toggle(String id) {
    final label = _labels.firstWhere((l) => l.id == id);
    if (_selected.contains(id)) {
      removeConversationLabel(widget.snackbarContext, _key, _messages, label);
    } else {
      _intents.add(_key, _messages, id);
    }
  }

  // ponytail: a creation refused (offline, Da ricollegare) leaves no trace; say it when the picker gets an error slot.
  Future<void> _create(String name) async {
    final r = await GetIt.I<MailSync>().createLabel(widget.accountId, name);
    if (r case Ok(:final value)) {
      // Queued behind the fetch, the picker maybe closed: the Conversazione is read again, not `_messages`.
      final all = await GetIt.I<InboxRepository>().watchConversation(widget.accountId, widget.conversationId).first;
      _intents.add(_key, [for (final m in all) m.message], value.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.selettoreEtichette;
    return PostinoLabelPicker(
      labels: [
        for (final l in _labels)
          if (l.kind == LabelKind.etichetta) (id: l.id, name: l.name),
      ],
      selected: _selected,
      onToggle: _toggle,
      onCreate: (name) => unawaited(_create(name)),
      validateName: (name) => switch (labelNameError(name, _labels.map((l) => l.name))) {
        null => null,
        LabelNameError.empty => t.errorEmpty,
        LabelNameError.emptyLevel => t.errorEmptyLevel,
        LabelNameError.duplicate => t.errorDuplicate,
      },
      strings: PostinoLabelPickerStrings(
        search: t.search,
        nestHelp: t.nestHelp,
        create: (name) => t.create(name: name),
        selected: (n) => t.selected(n: n),
        empty: t.empty,
      ),
    );
  }
}
