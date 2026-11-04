import 'package:drift/drift.dart';

import '../postino_database.dart';
import '../tables/trusted_senders_table.dart';

part 'trusted_senders_dao.g.dart';

@DriftAccessor(tables: [TrustedSenders])
class TrustedSendersDao extends DatabaseAccessor<PostinoDatabase> with _$TrustedSendersDaoMixin {
  TrustedSendersDao(super.attachedDatabase);

  /// [address] already normalized; adding it twice keeps one.
  Future<void> add(String address) =>
      into(trustedSenders).insert(TrustedSendersCompanion.insert(address: address), mode: InsertMode.insertOrIgnore);

  Stream<Set<String>> watchAll() => select(trustedSenders).map((r) => r.address).watch().map((a) => a.toSet());
}
