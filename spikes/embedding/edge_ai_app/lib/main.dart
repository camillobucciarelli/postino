// Spike #103 usa e getta: misura flutter_edge_ai + EmbeddingGemma 2 (.litertlm) sulle 80 email del dataset.
// ignore_for_file: experimental_member_use
// Headless: all'avvio esegue maxTokens 256 e 512 in sequenza, scrive i JSON e termina. Vedi README dello spike.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:path_provider/path_provider.dart';

/// Nome del file del modello senza `.litertlm`: variabile d'ambiente `EDGE_MODEL` (macOS) o
/// `--dart-define=MODEL=...` (mobile). Default `embeddinggemma-2-text-270m`; l'altro è `embeddinggemma-2-740m`.
final _model = Platform.environment['EDGE_MODEL'] ??
    const String.fromEnvironment('MODEL', defaultValue: 'embeddinggemma-2-text-270m');

/// Cartella del modello (`EDGE_MODEL_DIR`) e dei JSON (`EDGE_OUT_DIR`), solo macOS. Su mobile entrambe sono la
/// cartella dell'app (vedi README).
final _modelDir = Platform.environment['EDGE_MODEL_DIR'] ?? '';
final _dir = Platform.environment['EDGE_OUT_DIR'] ?? '';

// Copie identiche di eval/lib/embedding_text.dart.
String emailText({required String subject, required String from, required String body}) =>
    'Oggetto: $subject\nDa: $from\n\n$body';
String labelText({required String name, required String description}) => '$name: $description';

final _status = ValueNotifier('avvio');
void _log(String s) {
  stdout.writeln('[edge_ai] $s');
  _status.value = s;
}

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(body: Center(child: ValueListenableBuilder(valueListenable: _status, builder: (_, s, _) => Text(s)))),
    ),
  );
  _run().then((_) => exit(0), onError: (Object e, StackTrace st) async {
    _log('ERRORE: $e\n$st');
    await File('${await _workDir()}/edge_ai-error.txt').writeAsString('$e\n$st');
    exit(1);
  });
}

Future<String> _workDir() async => _dir.isNotEmpty
    ? _dir
    : (Platform.isAndroid ? (await getExternalStorageDirectory())! : await getApplicationDocumentsDirectory()).path;

int _mb(int bytes) => (bytes / (1024 * 1024)).round();

double _pct(List<double> sorted, double p) => sorted[((sorted.length - 1) * p).round()];

Future<void> _run() async {
  final dir = await _workDir();
  final modelPath = '${_modelDir.isNotEmpty ? _modelDir : dir}/$_model.litertlm';
  final platform = Platform.isMacOS ? 'macos' : (Platform.isIOS ? 'ios-sim' : 'android-emu');
  final data = jsonDecode(await rootBundle.loadString('assets/emails.json')) as Map<String, dynamic>;
  final cutsJson = jsonDecode(await rootBundle.loadString('assets/token_cuts.json')) as Map<String, dynamic>;
  final labels = (data['labels'] as List).cast<Map<String, dynamic>>();
  final emails = (data['emails'] as List).cast<Map<String, dynamic>>();
  final cacheDir = Directory('${(await getApplicationCacheDirectory()).path}/flutter_edge_ai/emb');

  await FlutterEdgeAi.initialize(embeddingBackends: const [LiteRtEmbeddingBackend()]);

  for (final maxTokens in const [256, 512]) {
    final cacheWarm = cacheDir.existsSync() && cacheDir.listSync(recursive: true).whereType<File>().isNotEmpty;
    final rssBefore = ProcessInfo.currentRss;
    _log('$maxTokens: load $modelPath');
    final sw = Stopwatch()..start();
    await FlutterEdgeAi.installEmbedder().modelFromFile(modelPath).install();
    final embedder = await FlutterEdgeAi.getActiveEmbedder();
    final loadMs = sw.elapsedMilliseconds;
    final rssAfterLoad = ProcessInfo.currentRss;

    // Il tokenizer offline (tool/token_cuts.py) deve contare come il motore: l'email più lunga ripetuta supera
    // 1024 token e il motore rifiuta riportando il conteggio esatto.
    final check = cutsJson['check'] as Map<String, dynamic>;
    final longest = emails.firstWhere((e) => e['id'] == check['id']);
    final lt = emailText(subject: longest['subject'], from: longest['from'], body: longest['body']);
    int? engineTokens;
    try {
      await embedder.embed(EmbeddingInput.text('$lt\n\n$lt'), taskType: TaskType.classification);
    } on EmbeddingInputTooLongException catch (e) {
      engineTokens = e.actualTokens;
    }

    final cuts = (cutsJson['cuts'] as Map<String, dynamic>)['$maxTokens'] as Map<String, dynamic>;
    String text(Map<String, dynamic> e) {
      final full = emailText(subject: e['subject'], from: e['from'], body: e['body']);
      return String.fromCharCodes(full.runes.take(cuts[e['id']] as int)); // i tagli sono in code point (Python)
    }

    for (final e in emails.take(3)) {
      await embedder.embed(EmbeddingInput.text(text(e)), taskType: TaskType.classification);
    }
    final latencies = <double>[];
    final emailOut = <Map<String, Object?>>[];
    for (final e in emails) {
      final t = text(e);
      sw.reset();
      final v = await embedder.embed(EmbeddingInput.text(t), taskType: TaskType.classification);
      latencies.add(sw.elapsedMicroseconds / 1000);
      emailOut.add({'id': e['id'], 'label': e['label'], 'lang': e['lang'], 'embedding': v});
    }
    final labelOut = <Map<String, Object?>>[];
    for (final l in labels) {
      final v = await embedder.embed(
        EmbeddingInput.text(labelText(name: l['name'], description: l['description'])),
        taskType: TaskType.classification,
      );
      labelOut.add({'name': l['name'], 'embedding': v});
    }
    final rssMaxAfterEmbed = ProcessInfo.maxRss;
    _log('$maxTokens: embedding fatti, decider');

    // createDecider: zero-shot con le sole descrizioni (prefisso sentenceSimilarity, fuori dalle misure di latenza).
    final decider = await embedder.createDecider(
      options: [for (final l in labels) DeciderOption(l['name'], description: labelText(name: l['name'], description: l['description']))],
      calibration: const EmbeddingDeciderCalibration.none(),
    );
    final hits = {'all': 0, 'it': 0, 'en': 0}, totals = {'all': 0, 'it': 0, 'en': 0};
    for (final e in emails) {
      final answer = await decider.choose(DeciderInput(EmbeddingInput.text(text(e))));
      for (final k in ['all', e['lang'] as String]) {
        totals[k] = totals[k]! + 1;
        if (answer.choice == e['label']) hits[k] = hits[k]! + 1;
      }
    }
    await decider.close();

    final name = 'edge_ai-$platform-${_model.replaceFirst('embeddinggemma-2-', 'eg2-')}-$maxTokens';
    final modelId = '$_model.litertlm +prefisso classification'; // niente "|": rompe la tabella di eval
    await File('$dir/$name.json').writeAsString(
      jsonEncode({'runtime': 'flutter_edge_ai', 'model': modelId, 'maxTokens': maxTokens, 'labels': labelOut, 'emails': emailOut}),
    );
    final sorted = [...latencies]..sort();
    await File('$dir/$name.metrics.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'runtime': 'flutter_edge_ai 2.5.5 + flutter_edge_ai_litertlm 1.19.1',
        'model': modelId,
        'modelBytes': File(modelPath).lengthSync(),
        'maxTokens': maxTokens,
        'platform': platform,
        'os': Platform.operatingSystemVersion,
        'cpus': Platform.numberOfProcessors,
        'backend': embedder.activeBackend?.name,
        'dim': embedder.dimension,
        'maxInputTokens': embedder.maxInputTokens,
        'weightCacheWarmBeforeLoad': cacheWarm,
        'loadMs': loadMs,
        'latencyMs': {
          'p50': _pct(sorted, .5),
          'p95': _pct(sorted, .95),
          'mean': latencies.reduce((a, b) => a + b) / latencies.length,
          'max': sorted.last,
          'perEmail': {for (var i = 0; i < emails.length; i++) emails[i]['id']: latencies[i]},
        },
        'rssMB': {'beforeLoad': _mb(rssBefore), 'afterLoad': _mb(rssAfterLoad), 'maxAfterEmbed': _mb(rssMaxAfterEmbed), 'maxAtEnd': _mb(ProcessInfo.maxRss)},
        'truncation': 'tagli esatti da tool/token_cuts.py (tokenizer.json di google/embeddinggemma-2), prefisso, BOS ed EOS inclusi',
        'tokenizerCheck': {'id': check['id'], 'offline': check['tokens'], 'engine': engineTokens},
        'decider': {
          'method': 'centroid, calibration none, sole descrizioni (prefisso sentenceSimilarity)',
          for (final k in totals.keys) k: hits[k]! / totals[k]!,
        },
      }),
    );
    await embedder.close();
    _log('$maxTokens: scritto $dir/$name.json');
  }
  await File('$dir/edge_ai-done.txt').writeAsString('ok');
}
