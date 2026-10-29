import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Goldens are recorded on macOS and checked on Linux CI: tolerate anti-aliasing noise, not real changes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final local = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _TolerantComparator(local.basedir.resolve('x.dart'));
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    try {
      if (result.passed || result.diffPercent <= 0.005) return true;
      throw FlutterError(await generateFailureOutput(result, golden, basedir));
    } finally {
      result.dispose();
    }
  }
}
