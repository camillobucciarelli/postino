import '../../domain/message.dart';
import '../json_objects.dart';
import 'gmail_http.dart';
import 'google_failure.dart';

/// The Account's Etichette on Gmail: `users.labels` and the label changes of `users.messages.modify`.
class GmailLabels(final GmailHttp _gmail) {
  /// The user labels: the system ones (INBOX, STARRED, UNREAD...) are inbox, Stella and read state, not Etichette.
  Future<List<Label>> list() async => [
    for (final l in jsonObjects((await _gmail.get('labels'))['labels']))
      if (l['type'] == 'user') Label(id: l['id'] as String, name: l['name'] as String, kind: LabelKind.etichetta),
  ];

  /// Listed first, so a repeated creation returns the existing Etichetta instead of Gmail's 409.
  /// Gmail label names are unique regardless of case.
  Future<Label> create(String name) async {
    if (await _named(name) case final existing?) return existing;
    try {
      final r = await _gmail.send(
        'POST',
        'labels',
        body: {'name': name, 'labelListVisibility': 'labelShow', 'messageListVisibility': 'show'},
      );
      return Label(id: r['id'] as String, name: r['name'] as String, kind: LabelKind.etichetta);
    } on GoogleFailed {
      // Another client created it between the list and the post: Gmail's 409.
      // ponytail: any refused post lists again (one GET); match the 409 alone if that ever costs.
      if (await _named(name) case final existing?) return existing;
      rethrow;
    }
  }

  Future<Label?> _named(String name) async =>
      (await list()).where((l) => l.name.toLowerCase() == name.toLowerCase()).firstOrNull;

  /// Removes all of [labelIds] in one `messages.modify`.
  Future<void> remove(String messageId, List<String> labelIds) =>
      _gmail.send('POST', 'messages/$messageId/modify', body: {'removeLabelIds': labelIds});

  /// Idempotent on Gmail: adding a label the message has, or removing one it lacks, changes nothing.
  Future<void> set(String messageId, String labelId, {required bool add}) => _gmail.send(
    'POST',
    'messages/$messageId/modify',
    body: {
      add ? 'addLabelIds' : 'removeLabelIds': [labelId],
    },
  );
}
