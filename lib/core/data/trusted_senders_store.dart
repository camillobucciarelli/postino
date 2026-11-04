import 'package:injectable/injectable.dart';

import '../domain/trusted_senders_repository.dart';
import 'postino_database.dart';

@LazySingleton(as: TrustedSendersRepository)
class TrustedSendersStore implements TrustedSendersRepository {
  TrustedSendersStore(this._db);
  final PostinoDatabase _db;
  final _shown = <(String, String)>{};

  @override
  Stream<Set<String>> watchTrusted() => _db.trustedSendersDao.watchAll();

  @override
  Future<void> trust(String from) => _db.trustedSendersDao.add(normalizeAddress(from));

  @override
  void showOnce(String accountId, String messageId) => _shown.add((accountId, messageId));

  @override
  bool shownOnce(String accountId, String messageId) => _shown.contains((accountId, messageId));
}
