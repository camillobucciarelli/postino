import '../../domain/action_outcome.dart';
import '../../domain/mail_action.dart';
import '../../domain/message.dart';
import '../../domain/result.dart';
import '../oauth/oauth_failed.dart';
import 'gmail_http.dart';
import 'gmail_labels.dart';
import 'gmail_message_parser.dart';

/// The Azioni on Gmail (ADR 0008): Gmail has no conditional write, so the message is read once
/// (`messages.get`, `format=minimal`), compared with the expected and the wanted value, and written
/// only if needed: at most one call for the attribute. Failures are thrown as [OAuthFailed].
class GmailActions(final GmailHttp _gmail, final GmailLabels _labels) {
  /// Applies [action] to [messageId]; [expected] null forces it. A message gone is [ActionMessageGone].
  Future<ActionOutcome> apply(String messageId, MailAction action, Object? expected) async {
    final Set<String> labels;
    try {
      labels = await _read(messageId);
    } on OAuthFailed catch (e) {
      if (e.failure is NotFoundFailure) return const ActionMessageGone();
      rethrow;
    }
    final current = _value(labels, action);
    // Already as wanted: nothing to write.
    if (current == action.wanted) return const ActionApplied();
    // Elimina never conflicts.
    if (expected != null && current != expected && action is! Delete) return ActionConflict(current);
    try {
      await _write(messageId, action, labels);
    } on OAuthFailed catch (e) {
      // Deleted between the read and the write.
      if (e.failure is NotFoundFailure) return const ActionMessageGone();
      rethrow;
    }
    return const ActionApplied();
  }

  Future<Set<String>> _read(String messageId) async {
    final j = await _gmail.get('messages/$messageId', query: {'format': 'minimal'});
    return gmailLabelIds(j).toSet();
  }

  /// The value of the attribute of [action] given the message's [labels].
  static Object _value(Set<String> labels, MailAction action) => switch (action) {
    MarkRead() || MarkUnread() => !labels.contains('UNREAD'),
    Star() || Unstar() => labels.contains(starredLabelId),
    Archive() || Delete() =>
      labels.contains(trashLabelId)
          ? Placement.trash
          : labels.contains(inboxLabelId)
          ? Placement.inbox
          : Placement.archive,
    ApplyLabel(:final labelId) || RemoveLabel(:final labelId) => labels.contains(labelId),
  };

  /// One write (5 quota units): a `messages.modify`, or `trash`.
  Future<void> _write(String messageId, MailAction action, Set<String> labels) => switch (action) {
    MarkRead() || MarkUnread() => _labels.set(messageId, 'UNREAD', add: action.wanted == false),
    Star() || Unstar() => _labels.set(messageId, starredLabelId, add: action.wanted == true),
    ApplyLabel(:final labelId) => _labels.set(messageId, labelId, add: true),
    RemoveLabel(:final labelId) => _labels.set(messageId, labelId, add: false),
    Delete() => _gmail.send('POST', 'messages/$messageId/trash'),
    // Out of the Cestino too, in the same modify.
    Archive() => _labels.remove(messageId, [inboxLabelId, if (labels.contains(trashLabelId)) trashLabelId]),
  };
}
