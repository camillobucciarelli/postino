import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/mail_sync.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/platform_services.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'label_picker_sheet.dart';

/// Opens the picker of the Etichette of a Conversazione, anchored to [anchor] (the «Etichette» button, a row of
/// the list); on closing the focus goes back to [returnFocus]. A removal's snackbar shows under [anchor]'s messenger.
Future<void> openLabelPicker(
  BuildContext anchor, {
  required String accountId,
  required String conversationId,
  FocusNode? returnFocus,
}) {
  final t = anchor.t.selettoreEtichette;
  return showPostinoPopover<void>(
    anchor,
    label: t.button,
    barrierLabel: t.close,
    returnFocus: returnFocus,
    builder: (_) => LabelPickerSheet(accountId: accountId, conversationId: conversationId, snackbarContext: anchor),
  );
}

/// Puts the Etichetta [labelId] on [messages] (with [add] false, takes it off): here at once, on the Provider
/// through the offline queue (#105), with a single replay for all of them.
void setLabelOn(String accountId, Iterable<Message> messages, String labelId, {required bool add}) =>
    unawaited(GetIt.I<MailSync>().setConversationLabel(accountId, [for (final m in messages) m.id], labelId, add: add));

/// Puts [labelId] on every message of a Conversazione that lacks it.
void addConversationLabel(String accountId, List<Message> messages, String labelId) =>
    setLabelOn(accountId, messages.where((m) => !m.labelIds.contains(labelId)), labelId, add: true);

/// Takes [label] off every message of a Conversazione that has it, then shows «Etichetta «X» tolta» under
/// [context]'s messenger, whose Annulla puts it back on those very messages and on those [onUndo] returns.
void removeConversationLabel(
  BuildContext context,
  String accountId,
  List<Message> messages,
  Label label, {
  Iterable<Message> Function()? onUndo,
}) {
  final had = messages.where((m) => m.labelIds.contains(label.id)).toList();
  setLabelOn(accountId, had, label.id, add: false);
  if (!context.mounted) return;
  final t = context.t.selettoreEtichette;
  final clock = GetIt.I<Clock>();
  PostinoSnackbar.show(
    context,
    message: t.removed(name: label.name),
    actionLabel: t.undo,
    until: clock.now().add(PostinoMotion.undoWindow),
    now: clock.now,
    onAction: () {
      setLabelOn(accountId, [...had, ...?onUndo?.call()], label.id, add: true);
    },
  );
}
