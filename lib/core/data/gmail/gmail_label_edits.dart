import '../../domain/message.dart';

/// The label changes a Gmail history reports for messages that need no download (#322), per message in history order:
/// the read and star state is the `UNREAD` and `STARRED` labels, so one list of changes says it all.
class GmailLabelEdits() {
  final _edits = <String, List<({bool added, List<String> labels})>>{};

  /// The messages with changes.
  Iterable<String> get ids => _edits.keys;

  void add(String id, {required bool added, required List<String> labels}) =>
      (_edits[id] ??= []).add((added: added, labels: labels));

  /// The message is downloaded or gone: its changes mean nothing.
  void forget(String id) => _edits.remove(id);

  /// [m] with the changes of its id, in order, and the read and star state they leave.
  Message applyTo(Message m) {
    final labels = [...m.labelIds];
    for (final e in _edits[m.id]!) {
      e.added ? labels.addAll(e.labels.where((l) => !labels.contains(l))) : labels.removeWhere(e.labels.contains);
    }
    return Message(
      id: m.id,
      messageId: m.messageId,
      conversationId: m.conversationId,
      labelIds: labels,
      isRead: !labels.contains('UNREAD'),
      isStarred: labels.contains(starredLabelId),
      from: m.from,
      fromName: m.fromName,
      to: m.to,
      cc: m.cc,
      bcc: m.bcc,
      subject: m.subject,
      snippet: m.snippet,
      date: m.date,
      replyTo: m.replyTo,
      references: m.references,
      hasAttachments: m.hasAttachments,
    );
  }
}
