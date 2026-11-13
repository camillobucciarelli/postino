import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../domain/contact_ranking.dart';
import '../../domain/message.dart' show sentLabelId;
import '../postino_database.dart';
import '../tables/accounts_table.dart';
import '../tables/message_labels_table.dart';
import '../tables/messages_table.dart';

part 'contacts_dao.g.dart';

/// The Contatti (#216) have no table of their own: they are read from the messages of every Account, by rowid so
/// that two reads can be merged. Sent: in the Inviati (the system Etichetta).
/// Each read takes the newest [_cap] messages: that bounds a one-letter prefix, which matches nearly every message;
/// past them a message weighs little (the score halves every 30 days) and there are many Contatti to choose from.
@DriftAccessor(tables: [Accounts, Messages, MessageLabels])
class ContactsDao(super.attachedDatabase) extends DatabaseAccessor<PostinoDatabase> with _$ContactsDaoMixin {
  static const _cap = 1000;

  /// The messages, of any Account, whose sender or recipients contain [prefix] somewhere.
  // ponytail: LIKE folds ASCII case only, so a non-ASCII prefix («él») skips the filter and reads the newest
  // messages; a table of Contatti (option (b) of #216) if those names go missing.
  Future<Map<int, ContactSighting>> sightings(String prefix) {
    final (where, args) = _byPrefix(prefix);
    return _select(where, args);
  }

  (String, List<String>) _byPrefix(String prefix) {
    if (prefix.runes.any((r) => r > 0x7f)) return ('', const []);
    final like = _like(prefix);
    return (
      'WHERE m.sender LIKE ? ESCAPE \'\\\' OR m.sender_name LIKE ? ESCAPE \'\\\' OR $_lines',
      [for (var i = 0; i < 5; i++) like],
    );
  }

  /// The SQLite query plan of [sightings], one line per step: what the tests check, instead of a wall clock.
  @visibleForTesting
  Future<List<String>> sightingsPlan(String prefix) async {
    final (where, args) = _byPrefix(prefix);
    final rows = await customSelect('EXPLAIN QUERY PLAN ${_sql(where)}', variables: _variables(args)).get();
    return [for (final r in rows) r.read<String>('detail')];
  }

  /// The messages from or to one of [addresses] (lowercase).
  Future<Map<int, ContactSighting>> sightingsOf(List<String> addresses) {
    if (addresses.isEmpty) return Future.value(const {});
    return _select('WHERE ${[for (final _ in addresses) '(lower(m.sender) = ? OR $_lines)'].join(' OR ')}', [
      for (final a in addresses) ...[a, for (var i = 0; i < 3; i++) _like(a)],
    ]);
  }

  /// Every Account's address, lowercase: never a Contatto.
  Future<Set<String>> ownAddresses() async =>
      (await select(accounts).get()).map((a) => a.address.toLowerCase()).toSet();

  static const _lines = "m.recipients LIKE ? ESCAPE '\\' OR m.cc LIKE ? ESCAPE '\\' OR m.bcc LIKE ? ESCAPE '\\'";

  static String _like(String s) => '%${s.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';

  static String _sql(String where) =>
      'SELECT m.rowid AS row, m.sender, m.sender_name, m.recipients, m.cc, m.bcc, m.date, '
      'EXISTS (SELECT 1 FROM message_labels l WHERE l.account_id = m.account_id AND l.message_id = m.id '
      'AND l.label_id = ?) AS sent '
      'FROM messages m $where ORDER BY m.date DESC LIMIT ?';

  static List<Variable> _variables(List<String> args) => [
    Variable.withString(sentLabelId),
    for (final a in args) Variable.withString(a),
    Variable.withInt(_cap),
  ];

  Future<Map<int, ContactSighting>> _select(String where, List<String> args) async {
    final rows = await customSelect(
      _sql(where),
      variables: _variables(args),
      readsFrom: {messages, messageLabels},
    ).get();
    List<String> lines(QueryRow r, String column) =>
        r.read<String>(column).split('\n').where((s) => s.isNotEmpty).toList();
    return {
      for (final r in rows)
        r.read<int>('row'): (
          sender: r.read<String>('sender'),
          senderName: r.readNullable<String>('sender_name'),
          recipients: [...lines(r, 'recipients'), ...lines(r, 'cc'), ...lines(r, 'bcc')],
          date: DateTime.fromMillisecondsSinceEpoch(r.read<int>('date'), isUtc: true),
          sent: r.read<bool>('sent'),
        ),
    };
  }
}
