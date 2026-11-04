// Tabella markdown da results/metrics/llamadart-*.metrics.json + results/raw/*.eval.json.
// Uso: dart run tool/table.dart   (dalla cartella llamadart_app)
import 'dart:convert';
import 'dart:io';

void main() {
  Map<String, dynamic> read(String p) => jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;
  String f(num x) => x.toStringAsFixed(x < 10 ? 1 : 0);
  String acc(Map<String, dynamic> e, String k) => (e[k]['all'] as num).toStringAsFixed(2);
  final rows = <String>[];
  final metrics = Directory('../results/metrics').listSync().whereType<File>().map((e) => e.path).where(
        (p) => p.contains('/llamadart-') && p.endsWith('.metrics.json'),
      ).toList()
    ..sort();
  for (final p in metrics) {
    final m = read(p);
    final stem = p.split('/').last.replaceAll('.metrics.json', '');
    for (final variant in [stem, '$stem-dim256']) {
      final evalFile = File('../results/raw/$variant.eval.json');
      if (!evalFile.existsSync()) continue;
      final e = read(evalFile.path);
      final lat = m['latencyMs'] as Map<String, dynamic>;
      final rss = m['rssMb'] as Map<String, dynamic>;
      final eff = m['maxTokensEffective'] != m['maxTokens'] ? ' (${m['maxTokensEffective']})' : '';
      rows.add(
        '| ${m['platform']} | ${(m['model'] as String).split(' ').first} | ${m['backend']} | ${m['maxTokens']}$eff '
        '| ${e['dim']} | ${m['loadMs']} / ${m['firstEmbedMs']} | ${f(lat['p50'] as num)} / ${f(lat['p95'] as num)} '
        '| ${f(rss['afterLoad'] as num)} / ${f(rss['maxAtEnd'] as num)} '
        '| ${acc(e, 'zeroShot')} | ${acc(e, 'knn5')} | ${acc(e, 'centroid')} |',
      );
    }
  }
  // ignore: avoid_print
  print(
    '| piattaforma | modello | backend | maxTok | dim | load / 1° embed ms | p50 / p95 ms per email '
    '| RSS dopo load / max MB | zero-shot | kNN5 | centroide |\n'
    '|---|---|---|---|---|---|---|---|---|---|---|\n${rows.join('\n')}',
  );
}
