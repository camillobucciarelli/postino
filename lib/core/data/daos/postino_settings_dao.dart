import 'package:drift/drift.dart';

import '../postino_database.dart';
import '../tables/postino_settings_table.dart';

part 'postino_settings_dao.g.dart';

@DriftAccessor(tables: [PostinoSettings])
class PostinoSettingsDao(super.attachedDatabase)
    extends DatabaseAccessor<PostinoDatabase>
    with _$PostinoSettingsDaoMixin {
  /// The value of [key] now, then each time it changes; null while missing.
  Stream<String?> watch(String key) =>
      (select(postinoSettings)..where((t) => t.key.equals(key))).map((r) => r.value).watchSingleOrNull();

  Future<String?> read(String key) async =>
      (await (select(postinoSettings)..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  /// A null [value] removes the voce.
  Future<void> write(String key, String? value) => value == null
      ? (delete(postinoSettings)..where((t) => t.key.equals(key))).go()
      : into(postinoSettings).insertOnConflictUpdate(PostinoSettingsCompanion.insert(key: key, value: value));
}
