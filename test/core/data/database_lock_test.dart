import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/database_lock.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;
  late String path;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('postino_lock');
    path = '${dir.path}/postino.db.lock';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a second holder waits for the first, gives up past its timeout; a failed body releases it', () async {
    final release = Completer<void>();
    final order = <String>[];
    final first = withDatabaseLock(path, () async {
      order.add('first');
      await release.future;
    });
    await expectLater(
      withDatabaseLock(path, () async => order.add('never'), timeout: const Duration(milliseconds: 100)),
      throwsA(isA<SqliteException>()),
    );
    final second = withDatabaseLock(path, () async => order.add('second'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(order, ['first'], reason: 'still waiting');
    release.complete();
    await first;
    await second;
    expect(order, ['first', 'second']);

    await expectLater(withDatabaseLock(path, () async => throw StateError('body')), throwsStateError);
    expect(await withDatabaseLock(path, () async => 'free again', timeout: Duration.zero), 'free again');
  });
}
