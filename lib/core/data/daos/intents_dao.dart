import 'package:drift/drift.dart';

import '../../domain/mail_action.dart';
import '../action_codec.dart';
import '../auto_labels_json.dart';
import '../postino_database.dart';
import '../tables/conflicts_table.dart';
import '../tables/intents_table.dart';

part 'intents_dao.g.dart';

/// The offline queue of the Azioni (ADR 0008): applied here at once, then replayed on the Provider.
@DriftAccessor(tables: [Intents, Conflicts])
class IntentsDao(super.attachedDatabase) extends DatabaseAccessor<PostinoDatabase> with _$IntentsDaoMixin {
  /// The Account's voci to replay at [now]: a «trattenuta» one waits for its deadline, which then lapses.
  Future<List<IntentRow>> pending(String accountId, {required int now}) => transaction(() async {
    await (update(intents)..where(
          (t) => t.accountId.equals(accountId) & t.heldUntil.isNotNull() & t.heldUntil.isSmallerOrEqualValue(now),
        ))
        .write(const IntentsCompanion(heldUntil: Value(null), previous: Value(null)));
    return (select(intents)..where((t) => t.accountId.equals(accountId) & t.heldUntil.isNull())).get();
  });

  /// Applies [action] to [messageIds] here at once and queues it, merging with the voce already on the same
  /// attribute: the last wanted value stays, with the first expected one. One transaction, so the messages of a
  /// Conversazione change all or none. [heldUntil] (ms since epoch) makes the voci «trattenute» until then.
  /// An Azione that changes nothing here queues nothing; one on an attribute in Conflitto closes it, expecting the
  /// Provider's value.
  Future<void> queue(String accountId, Iterable<String> messageIds, MailAction action, {int? heldUntil}) =>
      transaction(() async {
        final attribute = action.attribute;
        final wanted = encodeValue(action.wanted);
        final attributes = attachedDatabase.attributesDao;
        for (final messageId in messageIds) {
          final local = await attributes.read(accountId, messageId, attribute);
          // Gone from here (a sync removed it): nothing to change, nothing to replay.
          if (local == null) continue;
          final key = _key(accountId, messageId, attribute);
          final existing = await (select(intents)..where(key)).getSingleOrNull();
          final conflict = await (select(
            conflicts,
          )..where(_conflictKey(accountId, messageId, attribute))).getSingleOrNull();
          if (existing != null) {
            await (update(intents)..where(key)).write(
              IntentsCompanion(
                wanted: Value(wanted),
                heldUntil: Value(heldUntil),
                // ponytail: a held Azione over another held one: its Annulla brings back the first, no longer held.
                previous: Value(heldUntil == null ? null : existing.wanted),
              ),
            );
          } else if (conflict != null || local != wanted) {
            if (conflict != null) await (delete(conflicts)..where(_conflictKey(accountId, messageId, attribute))).go();
            await into(intents).insert(
              IntentsCompanion.insert(
                accountId: accountId,
                messageId: messageId,
                attribute: attribute,
                wanted: wanted,
                expected: Value(conflict?.provider ?? local),
                heldUntil: Value(heldUntil),
              ),
            );
          } else {
            continue;
          }
          await attributes.write(accountId, messageId, attribute, wanted);
        }
      });

  /// Annulla of the «trattenute» voci of [attribute] on [messageIds]: each leaves the queue and the message gets
  /// back its value here (the one before the held Azione). False when none was still held.
  Future<bool> cancelHeld(String accountId, Iterable<String> messageIds, String attribute) => transaction(() async {
    var any = false;
    final attributes = attachedDatabase.attributesDao;
    for (final messageId in messageIds) {
      final key = _key(accountId, messageId, attribute);
      final voce = await (select(intents)..where((t) => key(t) & t.heldUntil.isNotNull())).getSingleOrNull();
      if (voce == null) continue;
      any = true;
      if (voce.previous case final previous?) {
        await (update(intents)..where(key)).write(
          IntentsCompanion(wanted: Value(previous), heldUntil: const Value(null), previous: const Value(null)),
        );
        await attributes.write(accountId, messageId, attribute, previous);
      } else {
        await (delete(intents)..where(key)).go();
        if (voce.expected case final expected?) await attributes.write(accountId, messageId, attribute, expected);
      }
    }
    return any;
  });

  /// The voce reached the Provider as [wanted] (or its message is gone): it leaves; one changed meanwhile stays.
  Future<int> done(String accountId, String messageId, String attribute, String wanted) => (delete(
    intents,
  )..where((t) => _key(accountId, messageId, attribute)(t) & t.wanted.equals(wanted) & t.heldUntil.isNull())).go();

  /// The Provider has [provider], changed elsewhere: the voce becomes a Conflitto and the message keeps [wanted]
  /// here. One changed meanwhile stays queued instead.
  Future<void> conflict(String accountId, String messageId, String attribute, String wanted, String provider) =>
      transaction(() async {
        if (await done(accountId, messageId, attribute, wanted) == 0) return;
        await into(conflicts).insertOnConflictUpdate(
          ConflictsCompanion.insert(
            accountId: accountId,
            messageId: messageId,
            attribute: attribute,
            local: wanted,
            provider: provider,
          ),
        );
      });

  /// The Provider refused the voce: it leaves the queue and the message gets back [expected] here.
  /// One changed meanwhile stays, with its local change.
  Future<void> rejected(String accountId, String messageId, String attribute, String wanted, String? expected) =>
      transaction(() async {
        if (await done(accountId, messageId, attribute, wanted) == 0 || expected == null) return;
        await attachedDatabase.attributesDao.write(accountId, messageId, attribute, expected);
      });

  /// True when the message has an Etichetta dell'utente: one of the Account's labels (system ones are not there).
  Future<bool> hasUserLabel(String accountId, String messageId) async =>
      await customSelect(
        'SELECT 1 FROM message_labels ml JOIN labels l ON l.account_id = ml.account_id AND l.id = ml.label_id '
        'WHERE ml.account_id = ?1 AND ml.message_id = ?2 LIMIT 1',
        variables: [Variable(accountId), Variable(messageId)],
      ).getSingleOrNull() !=
      null;

  /// The Etichettatura automatica (#109) puts [labelId] on the message as [queue] does, unless the message
  /// has an Etichetta dell'utente or is gone, or the Etichetta is no longer automatica with the activation
  /// [activatedAt] the classification used: checked in the same transaction, so what the user did after the
  /// classification wins. False when skipped.
  Future<bool> queueAutoLabel(String accountId, String messageId, String labelId, {required int activatedAt}) =>
      transaction(() async {
        final config = autoLabelsOf(await attachedDatabase.postinoSettingsDao.readRow(autoLabelsKey(accountId)));
        final label = config[labelId];
        if (label == null || !label.automatic || label.activatedAt != activatedAt) return false;
        if (await hasUserLabel(accountId, messageId) ||
            await attachedDatabase.attributesDao.read(accountId, messageId, labelAttribute(labelId)) == null) {
          return false;
        }
        await queue(accountId, [messageId], ApplyLabel(labelId));
        return true;
      });

  Expression<bool> Function($IntentsTable) _key(String accountId, String messageId, String attribute) =>
      (t) => t.accountId.equals(accountId) & t.messageId.equals(messageId) & t.attribute.equals(attribute);

  Expression<bool> Function($ConflictsTable) _conflictKey(String accountId, String messageId, String attribute) =>
      (t) => t.accountId.equals(accountId) & t.messageId.equals(messageId) & t.attribute.equals(attribute);
}
