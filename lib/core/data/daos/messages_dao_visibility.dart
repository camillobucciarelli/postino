import 'package:drift/drift.dart';

import '../../domain/message.dart';
import '../postino_database.dart';
import 'messages_dao.dart';

/// Which messages a view shows: the one rule behind the lists, the unread, the reading view and its read marking.
extension MessagesDaoVisibility on MessagesDao {
  /// Whether the view [view] shows the message [t]. Cestino and Spam are views of their own (see the glossary): a
  /// message there keeps its other labels (Gmail, or the local Elimina until the Provider moves it) but shows in no
  /// other view, nor in its Conversazione opened from one. With both, the Cestino wins: Elimina from Spam adds TRASH
  /// here before the Provider takes SPAM away. Any other message shows, whatever its labels (a reply in Inviati too).
  Expression<bool> inView($MessagesTable t, Expression<String> view) {
    final x = alias(messageLabels, 'x');
    return notExistsQuery(
      select(x)..where(
        (x) =>
            x.accountId.equalsExp(t.accountId) &
            x.messageId.equalsExp(t.id) &
            (x.labelId.equals(trashLabelId) & view.equals(trashLabelId).not() |
                x.labelId.equals(spamLabelId) & view.isIn(const [spamLabelId, trashLabelId]).not()),
      ),
    );
  }
}
