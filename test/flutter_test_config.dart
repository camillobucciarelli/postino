import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carica le font reali per i golden (nei test altrimenti userebbero Ahem).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<ByteData> load(String f) async =>
      ByteData.sublistView(await File('assets/fonts/$f').readAsBytes());
  await (FontLoader(
    'Caprasimo',
  )..addFont(load('Caprasimo-Regular.ttf'))).load();
  await (FontLoader('Figtree')
        ..addFont(load('Figtree-Regular.ttf'))
        ..addFont(load('Figtree-SemiBold.ttf'))
        ..addFont(load('Figtree-Bold.ttf')))
      .load();
  await testMain();
}
