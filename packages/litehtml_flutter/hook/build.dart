import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

const _lh = 'third_party/litehtml';

/// Gumbo (C) come libreria statica, litehtml + wrapper (C++) come dinamica che la linka.
void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final logger = Logger('')
      ..level = Level.WARNING
      ..onRecord.listen((record) => stderr.writeln(record.message));
    final root = input.packageRoot.toFilePath();
    List<String> sources(String dir, String ext) =>
        Directory('$root$dir')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith(ext))
            .map((f) => f.path.substring(root.length))
            .toList();

    final includes = [
      '$_lh/include',
      '$_lh/include/litehtml',
      '$_lh/src/gumbo/include',
      '$_lh/src/gumbo/include/gumbo',
    ];
    await CBuilder.library(
      name: 'gumbo',
      sources: sources('$_lh/src/gumbo/', '.c'),
      includes: includes,
      std: 'c99',
      flags: ['-w'],
      linkModePreference: LinkModePreference.static,
    ).run(input: input, output: output, logger: logger);

    await CBuilder.library(
      name: 'litehtml_flutter',
      assetName: 'src/bindings.dart',
      sources: [...sources('$_lh/src/', '.cpp'), 'src/litehtml_c.cpp'],
      includes: [...includes, 'src'],
      language: Language.cpp,
      std: 'c++17',
      flags: ['-w'],
      libraries: ['gumbo'],
    ).run(input: input, output: output, logger: logger);
  });
}
