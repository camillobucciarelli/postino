import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/mail_notification.dart' show ConversationKey;
import '../../../core/domain/message.dart';
import '../../../core/domain/platform_services.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/conversation_label_intents.dart';
import 'label_picker_sheet.dart';

/// Opens the picker of the Etichette of a Conversazione, anchored to [anchor] (the «Etichette» button, a row of
/// the list); on closing the focus goes back to [returnFocus]. A removal's snackbar shows under [anchor]'s messenger.
Future<void> openLabelPicker(
  BuildContext anchor, {
  required String accountId,
  required String conversationId,
  required bool labelsAreFolders,
  FocusNode? returnFocus,
}) {
  final t = anchor.t.selettoreEtichette;
  return showPostinoPopover<void>(
    anchor,
    label: t.button,
    barrierLabel: t.close,
    returnFocus: returnFocus,
    builder: (_) => LabelPickerSheet(
      accountId: accountId,
      conversationId: conversationId,
      snackbarContext: anchor,
      labelsAreFolders: labelsAreFolders,
    ),
  );
}

/// Takes [label] off every message of the Conversazione [key] that has it (the older ones a running fetch brings
/// too), then shows «Etichetta «X» tolta» under [context]'s messenger, whose Annulla puts it back.
void removeConversationLabel(BuildContext context, ConversationKey key, List<Message> messages, Label label) {
  final intents = GetIt.I<ConversationLabelIntents>();
  final token = intents.remove(key, messages, label.id);
  if (!context.mounted) return intents.forget(token);
  final t = context.t.selettoreEtichette;
  final clock = GetIt.I<Clock>();
  unawaited(
    PostinoSnackbar.show(
      context,
      message: t.removed(name: label.name),
      actionLabel: t.undo,
      until: clock.now().add(PostinoMotion.undoWindow),
      now: clock.now,
      onAction: () => unawaited(intents.undoRemoval(token)),
    ).closed.then((_) => intents.forget(token)),
  );
}
