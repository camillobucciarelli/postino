import 'package:injectable/injectable.dart';

import '../domain/auto_label.dart';
import '../domain/auto_labels_repository.dart';
import 'auto_labels_json.dart';
import 'postino_database.dart';

// ponytail: local only, like every Impostazione di Postino in v1; the Drive sync (v1.1) uploads the same voce.
@LazySingleton(as: AutoLabelsRepository)
class AutoLabelsStore(final PostinoDatabase _db) implements AutoLabelsRepository {
  @override
  Stream<Map<String, AutoLabel>> watch(String accountId) =>
      _db.postinoSettingsDao.watch(_key(accountId)).map(decodeAutoLabels);

  @override
  Future<void> setAutomatic(String accountId, String labelId, {required bool automatic}) =>
      _update(accountId, labelId, (l) => (automatic: automatic, description: l.description));

  @override
  Future<void> setDescription(String accountId, String labelId, String? description) {
    final d = description?.trim();
    return _update(accountId, labelId, (l) => (automatic: l.automatic, description: d == null || d.isEmpty ? null : d));
  }

  /// Read, change one Etichetta, write: in a transaction, so two quick edits do not lose each other.
  Future<void> _update(String accountId, String labelId, AutoLabel Function(AutoLabel) change) =>
      _db.transaction(() async {
        final key = _key(accountId);
        final labels = decodeAutoLabels(await _db.postinoSettingsDao.read(key));
        labels[labelId] = change(labels[labelId] ?? (automatic: false, description: null));
        await _db.postinoSettingsDao.write(key, encodeAutoLabels(labels));
      });

  static String _key(String accountId) => 'auto_labels/$accountId';
}
