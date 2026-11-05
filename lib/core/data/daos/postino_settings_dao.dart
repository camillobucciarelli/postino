import 'dart:math';

import 'package:drift/drift.dart';

import '../../domain/settings_entry.dart';
import '../../domain/synced_settings.dart';
import '../postino_database.dart';
import '../tables/postino_settings_table.dart';

part 'postino_settings_dao.g.dart';

@DriftAccessor(tables: [PostinoSettings])
class PostinoSettingsDao(super.attachedDatabase)
    extends DatabaseAccessor<PostinoDatabase>
    with _$PostinoSettingsDaoMixin {
  /// The value of [key] now, then each time it changes; null while missing or removed.
  Stream<String?> watch(String key) => _live(key).map((r) => r.value).watchSingleOrNull();

  Future<String?> read(String key) async => (await _live(key).getSingleOrNull())?.value;

  /// The row of [key] now, then each time it changes; null while missing or removed.
  Stream<PostinoSettingRow?> watchRow(String key) => _live(key).watchSingleOrNull();

  /// The row of [key]; null when missing or removed.
  Future<PostinoSettingRow?> readRow(String key) => _live(key).getSingleOrNull();

  /// Writes the voce here, to upload; a null [value] writes a tombstone instead of deleting the row.
  /// Stamped [at], or just after the copy it replaces if that is later (a clock behind, a remote copy ahead):
  /// a local write always wins over what it replaces.
  Future<void> write(String key, String? value, {required DateTime at}) => transaction(() async {
    final old = await _row(key);
    await into(postinoSettings).insertOnConflictUpdate(
      PostinoSettingsCompanion.insert(
        key: key,
        value: Value(value),
        updatedAt: max(at.millisecondsSinceEpoch, (old?.updatedAt ?? -1) + 1),
        deviceId: await attachedDatabase.deviceSettingsDao.deviceId(),
        deleted: Value(value == null),
        dirty: true,
      ),
    );
  });

  /// Tombstones for every synced voce of [accountId], present here or not: the removal reaches every device.
  Future<void> tombstoneAccount(String accountId, {required DateTime at}) => transaction(() async {
    for (final key in accountSettingKeys(accountId)) {
      await write(key, null, at: at);
    }
  });

  /// Every voce, tombstones included.
  Future<List<SettingsEntry>> entries() async => [for (final r in await select(postinoSettings).get()) _entry(r)];

  /// How many voci wait to be uploaded, now and after each change.
  Stream<int> watchDirty() {
    final n = postinoSettings.key.count();
    return (selectOnly(postinoSettings)
          ..addColumns([n])
          ..where(postinoSettings.dirty))
        .map((r) => r.read(n)!)
        .watchSingle();
  }

  /// Takes the copies from elsewhere that win over the one here, as already uploaded.
  /// Checked again here, so a local write that came meanwhile is never overwritten.
  Future<void> applyRemote(Iterable<SettingsEntry> remote) => transaction(() async {
    for (final e in remote) {
      final old = await _row(e.key);
      // An exact tie goes to the remote copy (see mergeSettings).
      if (old != null && _entry(old).winsOver(e)) continue;
      await into(postinoSettings).insertOnConflictUpdate(
        PostinoSettingsCompanion.insert(
          key: e.key,
          value: Value(e.value),
          updatedAt: e.updatedAt,
          deviceId: e.deviceId,
          deleted: Value(e.deleted),
          dirty: false,
        ),
      );
    }
  });

  /// The [uploaded] copies are in the file: clean, unless written again since.
  Future<void> markClean(Iterable<SettingsEntry> uploaded) => transaction(() async {
    for (final e in uploaded) {
      await (update(postinoSettings)
            ..where((t) => t.key.equals(e.key) & t.updatedAt.equals(e.updatedAt) & t.deviceId.equals(e.deviceId)))
          .write(const PostinoSettingsCompanion(dirty: Value(false)));
    }
  });

  SimpleSelectStatement<$PostinoSettingsTable, PostinoSettingRow> _live(String key) =>
      select(postinoSettings)..where((t) => t.key.equals(key) & t.deleted.not());

  Future<PostinoSettingRow?> _row(String key) =>
      (select(postinoSettings)..where((t) => t.key.equals(key))).getSingleOrNull();

  static SettingsEntry _entry(PostinoSettingRow r) =>
      SettingsEntry(key: r.key, value: r.value, updatedAt: r.updatedAt, deviceId: r.deviceId, deleted: r.deleted);
}
