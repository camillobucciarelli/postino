import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

const _lh = 'third_party/litehtml';

/// Gumbo (C) come libreria statica, litehtml + wrapper (C++) come dinamica che la linka.
///
/// Provato su macOS, simulatore iOS ed emulatore Android; Windows (MSVC) e Linux (clang) compilati e con i test del
/// pacchetto verdi nei job `windows` e `linux` della CI, su runner GitHub-hosted (vedi `third_party/litehtml/VERSION`).
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
            .toList()
          ..sort();

    final os = input.config.code.targetOS;
    final msvc = os == OS.windows;
    // Il codice di terze parti si compila senza warning; MSVC vuole anche le eccezioni C++ (/EHsc: il wrapper le
    // cattura) e i sorgenti in UTF-8.
    final quiet = msvc ? ['/w', '/utf-8'] : ['-w'];
    final includes = [
      '$_lh/include',
      '$_lh/include/litehtml',
      '$_lh/src/gumbo/include',
      '$_lh/src/gumbo/include/gumbo',
      // strings.h di Gumbo per MSVC, come nel CMake di litehtml.
      if (msvc) '$_lh/src/gumbo/visualc/include',
    ];
    // I limiti di annidamento sono tarati sullo stack con -O3 (ADR 0025): fissato invece del default.
    const optimization = OptimizationLevel.o3;

    await CBuilder.library(
      name: 'gumbo',
      sources: sources('$_lh/src/gumbo/', '.c'),
      includes: includes,
      // MSVC non ha /std:c99; Gumbo compila col suo C di default, come nel CMake di litehtml.
      std: msvc ? null : 'c99',
      flags: quiet,
      optimizationLevel: optimization, // ignore: avoid_redundant_argument_values
      linkModePreference: LinkModePreference.static,
    ).run(input: input, output: output, logger: logger);

    await CBuilder.library(
      name: 'litehtml_flutter',
      assetName: 'src/bindings.dart',
      sources: [...sources('$_lh/src/', '.cpp'), 'src/litehtml_c.cpp', 'src/litehtml_export.cpp'],
      includes: [...includes, 'src'],
      language: Language.cpp,
      std: 'c++17',
      flags: [
        ...quiet,
        if (msvc) ...['/EHsc', '/permissive-'],
      ],
      optimizationLevel: optimization, // ignore: avoid_redundant_argument_values
      // libm esplicita: su Android senza di lei dlopen fallisce («cannot locate symbol atan2f»).
      libraries: ['gumbo', if (os == OS.android || os == OS.linux) 'm'],
      // Il default su Android è c++_shared, ma nessuno mette libc++_shared.so nell'APK: dlopen fallirebbe.
      cppLinkStdLib: os == OS.android ? 'c++_static' : null,
    ).run(input: input, output: output, logger: logger);
  });
}
