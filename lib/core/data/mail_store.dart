import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

import '../domain/account.dart';
import '../domain/inbox_repository.dart';
import '../domain/mail_provider.dart';
import '../domain/message.dart';
import 'postino_database.dart';

@lazySingleton
class MailStore implements InboxRepository {
  MailStore(PostinoDatabase db) : _db = db.sql;
  final Database _db;
  final _changed = StreamController<void>.broadcast(sync: true);

  void addAccount(Account a) {
    _db.execute('INSERT OR REPLACE INTO accounts VALUES (?, ?, ?, ?, ?, ?)', [
      a.id,
      a.address,
      a.provider.name,
      a.color,
      a.position,
      a.status.name,
    ]);
    _changed.add(null);
  }

  List<Account> accounts() => [
    for (final r in _db.select('SELECT * FROM accounts ORDER BY position'))
      Account(
        id: r['id'] as String,
        address: r['address'] as String,
        provider: ProviderKind.values.byName(r['provider'] as String),
        color: r['color'] as int,
        position: r['position'] as int,
        status: AccountStatus.values.byName(r['status'] as String),
      ),
  ];

  /// [fullSnapshot]: the batch is the Account's whole state, so cached messages absent from it are gone from the Provider.
  void applySync(
    String accountId,
    SyncBatch batch, {
    bool fullSnapshot = false,
  }) {
    _db.execute('BEGIN');
    try {
      if (fullSnapshot) {
        // Ids go through a TEMP table, not bound variables: SQLite caps those.
        _db
          ..execute(
            'CREATE TEMP TABLE IF NOT EXISTS snapshot_ids (id TEXT PRIMARY KEY)',
          )
          ..execute('DELETE FROM snapshot_ids');
        final insert = _db.prepare(
          'INSERT OR IGNORE INTO snapshot_ids VALUES (?)',
        );
        for (final m in batch.messages) {
          insert.execute([m.id]);
        }
        insert.close();
        const gone =
            'account_id = ? AND id NOT IN (SELECT id FROM snapshot_ids)';
        _db.execute(
          'DELETE FROM message_labels WHERE account_id = ? AND message_id IN '
          '(SELECT id FROM messages WHERE $gone)',
          [accountId, accountId],
        );
        _db.execute('DELETE FROM messages WHERE $gone', [accountId]);
      }
      for (final l in batch.labels) {
        _db.execute('INSERT OR REPLACE INTO labels VALUES (?, ?, ?, ?)', [
          accountId,
          l.id,
          l.name,
          l.kind.name,
        ]);
      }
      for (final m in batch.messages) {
        _db.execute(
          'INSERT OR REPLACE INTO messages VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            accountId,
            m.id,
            m.messageId,
            m.conversationId,
            m.from,
            m.to.join(','),
            m.subject,
            m.snippet,
            m.date.millisecondsSinceEpoch,
            m.isRead ? 1 : 0,
            m.isStarred ? 1 : 0,
          ],
        );
        _db.execute(
          'DELETE FROM message_labels WHERE account_id = ? AND message_id = ?',
          [accountId, m.id],
        );
        for (final l in m.labelIds) {
          _db.execute('INSERT INTO message_labels VALUES (?, ?, ?)', [
            accountId,
            m.id,
            l,
          ]);
        }
      }
      for (final id in batch.removedMessageIds) {
        _db.execute('DELETE FROM messages WHERE account_id = ? AND id = ?', [
          accountId,
          id,
        ]);
        _db.execute(
          'DELETE FROM message_labels WHERE account_id = ? AND message_id = ?',
          [accountId, id],
        );
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    _changed.add(null);
  }

  List<InboxEntry> _inbox() {
    final byId = {for (final a in accounts()) a.id: a};
    return [
      for (final r in _db.select(
        'SELECT m.* FROM messages m JOIN message_labels l '
        'ON l.account_id = m.account_id AND l.message_id = m.id AND l.label_id = ? '
        'ORDER BY m.date DESC, m.id',
        [inboxLabelId],
      ))
        if (byId[r['account_id']] case final account?)
          InboxEntry(
            account: account,
            message: Message(
              id: r['id'] as String,
              messageId: r['message_id'] as String,
              conversationId: r['conversation_id'] as String,
              labelIds: const [inboxLabelId],
              isRead: r['is_read'] == 1,
              isStarred: r['is_starred'] == 1,
              from: r['sender'] as String,
              to: (r['recipients'] as String).split(','),
              subject: r['subject'] as String,
              snippet: r['snippet'] as String,
              date: DateTime.fromMillisecondsSinceEpoch(
                r['date'] as int,
                isUtc: true,
              ),
            ),
          ),
    ];
  }

  @override
  Stream<List<InboxEntry>> watchUnifiedInbox() {
    late StreamController<List<InboxEntry>> out;
    StreamSubscription<void>? sub;
    out = StreamController(
      onListen: () {
        out.add(_inbox());
        sub = _changed.stream.listen((_) => out.add(_inbox()));
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }
}

@module
abstract class MailStoreModule {
  /// The UI sees the store only through [InboxRepository].
  @lazySingleton
  InboxRepository inboxRepository(MailStore store) => store;
}
