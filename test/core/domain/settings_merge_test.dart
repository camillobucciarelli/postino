// Last-write-wins per voce (#124, ADR 0016).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/settings_entry.dart';
import 'package:postino/core/domain/settings_merge.dart';

SettingsEntry _e(String key, String? value, int at, [String device = 'A']) =>
    SettingsEntry(key: key, value: value, updatedAt: at, deviceId: device, deleted: value == null);

void main() {
  group('merge', () {
    test('the later write wins; on a tie the greater device', () {
      final merged = mergeSettings(
        {'k': _e('k', '1', 10), 't': _e('t', '1', 10)},
        {'k': _e('k', '2', 11, 'B'), 't': _e('t', '2', 10, 'B')},
      );
      expect(merged['k']!.value, '2');
      expect(merged['t']!.value, '2');
      expect(mergeSettings({'k': _e('k', '1', 12)}, {'k': _e('k', '2', 11, 'B')})['k']!.value, '1');
    });

    test('different keys are both kept', () {
      expect(mergeSettings({'a': _e('a', '1', 1)}, {'b': _e('b', '2', 1)}).keys, ['a', 'b']);
    });

    test('a tombstone is not resurrected by an older copy', () {
      final merged = mergeSettings({'k': _e('k', null, 20)}, {'k': _e('k', '1', 10, 'B')});
      expect(merged['k']!.deleted, isTrue);
    });
  });
}
