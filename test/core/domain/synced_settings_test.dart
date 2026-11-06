// The closed list of synced Impostazioni di Postino (#124, ADR 0016).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/synced_settings.dart';

void main() {
  test('only the closed list syncs', () {
    expect(isSyncedSetting('auto_labels/a1'), isTrue);
    expect(isSyncedSetting('swipe/left'), isTrue);
    expect(isSyncedSetting('sidebar_expanded'), isFalse);
    // swipe/ is not per Account: removing an Account writes no tombstone for it.
    expect(accountSettingKeys('a1'), ['auto_labels/a1']);
  });
}
