import 'dart:convert';
import 'dart:io';

import 'package:embedding_eval/eval.dart';

/// `dart run bin/eval.dart <file.json> [...]`: una riga di tabella markdown per file
/// e un `<file>.eval.json` accanto a ciascun input.
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Uso: dart run bin/eval.dart <file.json> [<file2.json> ...]');
    exit(64);
  }
  String pct(Object? x) => x == null ? '-' : (x as double).toStringAsFixed(2);
  String acc(Object? m) {
    final a = m! as Map<String, Object?>;
    return '${pct(a['all'])} (${pct(a['it'])}/${pct(a['en'])})';
  }

  final marginCols = [for (final m in zeroShotMargins) 'ZS m≥$m cov/prec'];
  stdout
    ..writeln(
      '| file | runtime | model | maxTok | dim | n | zero-shot (IT/EN) | kNN3 (IT/EN) | kNN5 (IT/EN) '
      '| centroide (IT/EN) | ${marginCols.join(' | ')} |',
    )
    ..writeln('|${List.filled(10 + marginCols.length, '---').join('|')}|');

  for (final path in args) {
    final summary = evaluate(parseRun(jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>));
    final out = '${path.endsWith('.json') ? path.substring(0, path.length - 5) : path}.eval.json';
    File(out).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));
    final margins = [
      for (final m in (summary['zeroShotMargin']! as List<Object?>).cast<Map<String, Object?>>())
        '${pct(m['coverage'])}/${pct(m['precision'])}',
    ];
    stdout.writeln(
      '| ${path.split('/').last} | ${summary['runtime']} | ${summary['model']} | ${summary['maxTokens']} '
      '| ${summary['dim']} | ${summary['n']} | ${acc(summary['zeroShot'])} | ${acc(summary['knn3'])} '
      '| ${acc(summary['knn5'])} | ${acc(summary['centroid'])} | ${margins.join(' | ')} |',
    );
  }
}
