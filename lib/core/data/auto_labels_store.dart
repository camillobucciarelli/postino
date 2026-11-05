import 'package:injectable/injectable.dart';

import '../domain/auto_label.dart';
import '../domain/auto_labels_repository.dart';
import '../domain/platform_services.dart';
import 'auto_labels_json.dart';
import 'postino_database.dart';

/// The voce `auto_labels/<accountId>` of the Impostazioni di Postino: SettingsSync uploads it (ADR 0016).
@LazySingleton(as: AutoLabelsRepository)
class AutoLabelsStore(final PostinoDatabase _db, final Clock _clock) implements AutoLabelsRepository {
  @override
  Stream<Map<String, AutoLabel>> watch(String accountId) =>
      _db.postinoSettingsDao.watchRow(autoLabelsKey(accountId)).map(autoLabelsOf);

  @override
  Future<void> setAutomatic(String accountId, String labelId, {required bool automatic}) => _update(
    accountId,
    labelId,
    (l) => (
      automatic: automatic,
      description: l.description,
      // Stamped when the switch goes on, kept while it stays on, cleared when it goes off.
      activatedAt: !automatic ? null : l.activatedAt ?? _clock.now().millisecondsSinceEpoch,
    ),
  );

  @override
  Future<void> setDescription(String accountId, String labelId, String? description) {
    final d = description?.trim();
    return _update(
      accountId,
      labelId,
      (l) => (automatic: l.automatic, description: d == null || d.isEmpty ? null : d, activatedAt: l.activatedAt),
    );
  }

  /// Read, change one Etichetta, write: in a transaction, so two quick edits do not lose each other.
  Future<void> _update(String accountId, String labelId, AutoLabel Function(AutoLabel) change) =>
      _db.transaction(() async {
        final key = autoLabelsKey(accountId);
        final labels = autoLabelsOf(await _db.postinoSettingsDao.readRow(key));
        labels[labelId] = change(labels[labelId] ?? autoLabelDefault);
        await _db.postinoSettingsDao.write(key, encodeAutoLabels(labels), at: _clock.now());
      });
}
