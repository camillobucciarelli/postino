import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/label_name.dart';
import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/result.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
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

  /// The whole Conversazione brought here: from the list it may never have been opened, and the sync window leaves
  /// its older messages out. Offline or failed, the local messages are what there is.
  late final Future<Result<void>> _complete;

  @override
  void initState() {
    super.initState();
    final repo = GetIt.I<InboxRepository>();
    _complete = GetIt.I<MailSync>().completeConversation(widget.accountId, widget.conversationId);
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

  /// The messages to act on: the fetch of the whole Conversazione is waited for a moment (it is started when the
  /// picker opens); late or failed, the local ones go, never losing the intent.
  Future<List<Message>> _all() async {
    await _complete.timeout(const Duration(seconds: 2), onTimeout: () => const Ok(null));
    final c = await GetIt.I<InboxRepository>().watchConversation(widget.accountId, widget.conversationId).first;
    return [for (final m in c) m.message];
  }

  Future<void> _toggle(String id) async {
    final label = _labels.firstWhere((l) => l.id == id);
    final remove = _selected.contains(id);
    final messages = await _all();
    if (remove) {
      // ignore: use_build_context_synchronously, the removal goes through anyway; the snackbar checks `mounted`
      removeConversationLabel(widget.snackbarContext, widget.accountId, messages, label);
    } else {
      addConversationLabel(widget.accountId, messages, id);
    }
  }

  // ponytail: a creation refused (offline, Da ricollegare) leaves no trace; say it when the picker gets an error slot.
  Future<void> _create(String name) async {
    final r = await GetIt.I<MailSync>().createLabel(widget.accountId, name);
    if (r case Ok(:final value)) addConversationLabel(widget.accountId, await _all(), value.id);
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
      onToggle: (id) => unawaited(_toggle(id)),
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
