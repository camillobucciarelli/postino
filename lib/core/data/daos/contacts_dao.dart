import 'package:drift/drift.dart';

import '../../domain/contact_ranking.dart';
import '../../domain/message.dart' show sentLabelId;
import '../postino_database.dart';
import '../tables/accounts_table.dart';
import '../tables/message_labels_table.dart';
import '../tables/messages_table.dart';

part 'contacts_dao.g.dart';

/// The Contatti (#216) have no table of their own: they are read from the messages of every Account.
@DriftAccessor(tables: [Accounts, Messages, MessageLabels])
class ContactsDao(super.attachedDatabase) extends DatabaseAccessor<PostinoDatabase> with _$ContactsDaoMixin {
  /// The [limit] most recent messages, of any Account, whose sender or recipients contain [prefix] somewhere: a
  /// superset of those `rankContacts` keeps. Sent: in the Inviati (the system Etichetta).
  /// The cap bounds a one-letter prefix, which matches nearly every message: past the newest [limit] matches a
  /// message weighs little (the score halves every 30 days) and there are already many Contatti to choose from.
  // ponytail: LIKE folds ASCII case only, so a non-ASCII prefix («él») skips the filter and reads the newest
  // [limit] messages; a table of Contatti (option (b) of #216) if those names go missing.
  Future<List<ContactSighting>> sightings(String prefix, {int limit = 2000}) {
    final ascii = !prefix.runes.any((r) => r > 0x7f);
    final pattern = '%${prefix.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
    final like = ascii
        ? "WHERE m.sender LIKE ?1 ESCAPE '\\' OR m.sender_name LIKE ?1 ESCAPE '\\' "
              "OR m.recipients LIKE ?1 ESCAPE '\\' OR m.cc LIKE ?1 ESCAPE '\\' OR m.bcc LIKE ?1 ESCAPE '\\'"
        : '';
    return customSelect(
      'SELECT m.sender, m.sender_name, m.recipients, m.cc, m.bcc, m.date, '
      'EXISTS (SELECT 1 FROM message_labels l WHERE l.account_id = m.account_id AND l.message_id = m.id '
      'AND l.label_id = ?2) AS sent '
      'FROM messages m $like ORDER BY m.date DESC LIMIT ?3',
      variables: [Variable.withString(pattern), Variable.withString(sentLabelId), Variable.withInt(limit)],
      readsFrom: {messages, messageLabels},
    ).map((r) {
      List<String> lines(String column) => r.read<String>(column).split('\n').where((s) => s.isNotEmpty).toList();
      return (
        sender: r.read<String>('sender'),
        senderName: r.readNullable<String>('sender_name'),
        recipients: [...lines('recipients'), ...lines('cc'), ...lines('bcc')],
        date: DateTime.fromMillisecondsSinceEpoch(r.read<int>('date'), isUtc: true),
        sent: r.read<bool>('sent'),
      );
    }).get();
  }

  /// Every Account's address, lowercase: never a Contatto.
  Future<Set<String>> ownAddresses() async =>
      (await select(accounts).get()).map((a) => a.address.toLowerCase()).toSet();
}
