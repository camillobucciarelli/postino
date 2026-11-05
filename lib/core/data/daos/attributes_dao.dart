import 'package:drift/drift.dart';

import '../../domain/mail_action.dart';
import '../../domain/message.dart';
import '../action_codec.dart';
import '../postino_database.dart';
import '../tables/message_labels_table.dart';
import '../tables/messages_table.dart';

part 'attributes_dao.g.dart';

/// The attributes an Azione changes, as the message has them here, encoded by `action_codec.dart`:
/// `read` and `starred` are columns, the placement is the INBOX and TRASH labels, an Etichetta its label.
@DriftAccessor(tables: [Messages, MessageLabels])
class AttributesDao(super.attachedDatabase) extends DatabaseAccessor<PostinoDatabase> with _$AttributesDaoMixin {
  /// The message's value for [attribute]; null when the message is not here.
  Future<String?> read(String accountId, String messageId, String attribute) async {
    final m = await (select(
      messages,
    )..where((t) => t.accountId.equals(accountId) & t.id.equals(messageId))).getSingleOrNull();
    if (m == null) return null;
    final labels = {
      for (final l in await (select(
        messageLabels,
      )..where((t) => t.accountId.equals(accountId) & t.messageId.equals(messageId))).get())
        l.labelId,
    };
    return encodeValue(switch (attribute) {
      readAttribute => m.isRead,
      starredAttribute => m.isStarred,
      placementAttribute =>
        labels.contains(trashLabelId)
            ? Placement.trash
            : labels.contains(inboxLabelId)
            ? Placement.inbox
            : Placement.archive,
      _ => labels.contains(labelIdOf(attribute)),
    });
  }

  /// Gives the message [value] for [attribute] here; nothing when the message is not here (no orphan label).
  Future<void> write(String accountId, String messageId, String attribute, String value) async {
    final row = (select(messages)..where((t) => t.accountId.equals(accountId) & t.id.equals(messageId)));
    if (await row.getSingleOrNull() == null) return;
    final v = decodeValue(attribute, value);
    switch (attribute) {
      case readAttribute:
        await (update(messages)..where((t) => t.accountId.equals(accountId) & t.id.equals(messageId))).write(
          MessagesCompanion(isRead: Value(v == true)),
        );
      case starredAttribute:
        await (update(messages)..where((t) => t.accountId.equals(accountId) & t.id.equals(messageId))).write(
          MessagesCompanion(isStarred: Value(v == true)),
        );
        await _label(accountId, messageId, starredLabelId, on: v == true);
      case placementAttribute:
        await _label(accountId, messageId, inboxLabelId, on: v == Placement.inbox);
        await _label(accountId, messageId, trashLabelId, on: v == Placement.trash);
      default:
        await _label(accountId, messageId, labelIdOf(attribute)!, on: v == true);
    }
  }

  Future<void> _label(String accountId, String messageId, String labelId, {required bool on}) async {
    if (on) {
      await into(messageLabels).insert(
        MessageLabelsCompanion.insert(accountId: accountId, messageId: messageId, labelId: labelId),
        mode: InsertMode.insertOrIgnore,
      );
    } else {
      await (delete(
        messageLabels,
      )..where((t) => t.accountId.equals(accountId) & t.messageId.equals(messageId) & t.labelId.equals(labelId))).go();
    }
  }
}
