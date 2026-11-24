import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:litehtml_flutter/litehtml_flutter.dart';

import 'bench.dart';
import 'report.dart';

/// Harness #66. HTML e output stanno fuori dal repo (newsletter reali = dati di terzi):
///   fvm flutter run -d macos --release --dart-define=LH_IN=/a.html,/b.html --dart-define=LH_OUT=/cartella
///   [--dart-define=LH_EXIT=true] [--dart-define=LH_RUNS=11]
/// Scrive `<email>-<larghezza>-litehtml.png` e `measurements.md` in LH_OUT, poi mostra la prima email.
const _inputs = String.fromEnvironment('LH_IN');
const _out = String.fromEnvironment('LH_OUT');
const _runs = int.fromEnvironment('LH_RUNS', defaultValue: 11);
const _exit = bool.fromEnvironment('LH_EXIT');
const _widths = [700.0, 1000.0];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final files = _inputs.split(',').where((p) => p.isNotEmpty).toList();
  final htmls = {for (final f in files) _name(f): utf8.decode(File(f).readAsBytesSync(), allowMalformed: true)};
  if (htmls.isNotEmpty && _out.isNotEmpty) {
    final results = <BenchResult>[];
    for (final MapEntry(key: name, value: html) in htmls.entries) {
      for (final width in _widths) {
        results.add(await bench(name, html, width, _runs, '$_out/$name-${width.round()}-litehtml.png'));
      }
    }
    final mode = kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug');
    File('$_out/measurements-$mode.md').writeAsStringSync(report(results, mode: mode));
    if (_exit) exit(0);
  }
  runApp(_Demo(htmls.values.firstOrNull ?? '<p>Passa LH_IN con --dart-define.</p>'));
}

String _name(String path) => path.split('/').last.replaceAll('.html', '');

class _Demo extends StatelessWidget {
  const _Demo(this.html);

  final String html;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: LitehtmlView(html: html, width: 700),
        ),
      ),
    ),
  );
}
