// macOS quarantine of the attachment copies (#75): Gatekeeper checks a quarantined file before it runs.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/platform_services.dart';

void main() {
  late File file;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('postino-quarantine');
    addTearDown(() => dir.delete(recursive: true));
    file = File('${dir.path}/setup.exe')..writeAsStringSync('MZ');
  });

  Future<String> attribute() async {
    final r = await Process.run('/usr/bin/xattr', [
      '-p',
      'com.apple.quarantine',
      file.path,
    ]);
    return r.stdout as String;
  }

  test(
    'on macOS the file gets com.apple.quarantine, flagged as Postino\'s download',
    () async {
      await quarantine(file.path, platform: TargetPlatform.macOS);
      final value = await attribute();
      expect(value, startsWith('0081;'));
      expect(value, contains(';Postino;'));
    },
    skip: Platform.isMacOS
        ? false
        : 'com.apple.quarantine exists on macOS only',
  );

  test(
    'elsewhere it does nothing',
    () async {
      await quarantine(file.path, platform: TargetPlatform.linux);
      expect(await attribute(), isEmpty);
    },
    skip: Platform.isMacOS
        ? false
        : 'com.apple.quarantine exists on macOS only',
  );
}
