import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/attachment_crypto.dart';
import 'package:postino/core/data/error_log/log_keys.dart';

void main() {
  test('the log keys come from the database key, but are neither it nor each other', () {
    final databaseKey = 'ab' * 32;
    final keys = logKeysFrom(databaseKey);
    expect(keys.enc, hasLength(32));
    expect(keys.mac, hasLength(32));
    expect(keys.enc, isNot(keys.mac));
    expect(keys.enc, isNot(bytesFromHex(databaseKey)));
    expect(keys.mac, isNot(bytesFromHex(databaseKey)));
    expect(logKeysFrom(databaseKey).enc, keys.enc, reason: 'same database key, same log keys');
    expect(logKeysFrom('cd' * 32).enc, isNot(keys.enc));
  });
}
