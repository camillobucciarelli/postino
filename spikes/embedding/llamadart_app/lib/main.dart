// Spike #103: benchmark headless degli embedding con llamadart. Codice usa e getta.
//
// Configurazione (la prima fonte che c'è vince): variabile d'ambiente, file `<BASE>/job.json`
// (per Android, dove non si passano env), `--dart-define`.
//   BASE   cartella con i modelli; in output scrive `<BASE>/out/`
//   DATA   percorso di emails.json (default `<BASE>/emails.json`)
//   MODEL  file del modello in BASE (vuoto = tutti i modelli noti presenti, in sequenza)
//   MAXTOK 256 | 512 (vuoto = entrambi)
//   DEVICE auto | cpu | gpu (solo GGUF; LiteRT-LM è sempre CPU)
//   PLATFORM etichetta nei nomi file (default Platform.operatingSystem)
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:llamadart/llamadart.dart';

const _defines = {
  'BASE': String.fromEnvironment('BASE'),
  'DATA': String.fromEnvironment('DATA'),
  'MODEL': String.fromEnvironment('MODEL'),
  'MAXTOK': String.fromEnvironment('MAXTOK'),
  'DEVICE': String.fromEnvironment('DEVICE'),
  'PLATFORM': String.fromEnvironment('PLATFORM'),
};

/// Modelli noti: file → (nome, formato del testo, profilo EG2?).
final _models = <String, ({String name, String Function(String) format, bool eg2})>{
  'eg2-q8_0.gguf': (name: 'eg2-q8_0', format: _eg2, eg2: true),
  'eg2-bf16.gguf': (name: 'eg2-bf16', format: _eg2, eg2: true),
  'eg2-740m.litertlm': (name: 'eg2-740m-litertlm', format: _eg2, eg2: true),
  'eg2-270m.litertlm': (name: 'eg2-270m-litertlm', format: _eg2, eg2: true),
  'granite-97m-r2-q8_0.gguf': (name: 'granite-97m-r2-q8_0', format: (t) => t, eg2: false),
  'e5-small-q8_0.gguf': (name: 'e5-small-q8_0', format: (t) => 'query: $t', eg2: false),
};

// Stesso prefisso di LlamaEmbeddingText.query(task: classification); serve per contare i token.
String _eg2(String t) => 'task: classification | query: $t';

// Copie di spikes/embedding/eval/lib/embedding_text.dart.
String emailText({required String subject, required String from, required String body}) =>
    'Oggetto: $subject\nDa: $from\n\n$body';
String labelText({required String name, required String description}) => '$name: $description';

late Map<String, String> _cfg;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Center(child: Text('spike #103', textDirection: TextDirection.ltr)));
  var code = 0;
  try {
    _cfg = await _config();
    _log('config $_cfg');
    final models = _cfg['MODEL']!.isEmpty
        ? _models.keys.where((f) => File('${_cfg['BASE']}/$f').existsSync()).toList()
        : [_cfg['MODEL']!];
    final maxToks = _cfg['MAXTOK']!.isEmpty ? [256, 512] : [int.parse(_cfg['MAXTOK']!)];
    for (final m in models) {
      for (final t in maxToks) {
        await _run(m, t);
      }
    }
  } catch (e, s) {
    code = 1;
    _log('ERRORE $e\n$s');
    try {
      await _write('error.txt', '$e\n$s');
    } catch (_) {}
  }
  _log('FINE');
  exit(code);
}

Future<Map<String, String>> _config() async {
  final env = Platform.environment;
  var base = env['BASE'] ?? _defines['BASE']!;
  // Su iOS l'app non vede l'ambiente (HOME e SIMCTL_CHILD_* assenti): systemTemp è <container>/tmp.
  if (base.isEmpty && Platform.isIOS) base = '${Directory.systemTemp.parent.path}/Documents';
  if (base.isEmpty && Platform.isAndroid) {
    base = '/storage/emulated/0/Android/data/dev.postino.spike.llamadart_app/files';
  }
  final jobFile = File('$base/job.json');
  final job = jobFile.existsSync()
      ? (jsonDecode(await jobFile.readAsString()) as Map).cast<String, String>()
      : const <String, String>{};
  String get(String k) => env[k] ?? job[k] ?? _defines[k]!;
  return {
    'BASE': base,
    'DATA': get('DATA').isEmpty ? '$base/emails.json' : get('DATA'),
    'MODEL': get('MODEL'),
    'MAXTOK': get('MAXTOK'),
    'DEVICE': get('DEVICE').isEmpty ? 'auto' : get('DEVICE'),
    'PLATFORM': get('PLATFORM').isEmpty ? Platform.operatingSystem : get('PLATFORM'),
  };
}

Future<void> _run(String file, int maxTok) async {
  final spec = _models[file]!;
  final data = jsonDecode(await File(_cfg['DATA']!).readAsString()) as Map<String, dynamic>;
  final labels = (data['labels'] as List).cast<Map<String, dynamic>>();
  final emails = (data['emails'] as List).cast<Map<String, dynamic>>();
  final litert = file.endsWith('.litertlm');
  final device = switch (_cfg['DEVICE']) {
    'cpu' => ComputeDevice.cpu,
    'gpu' => ComputeDevice.gpu,
    _ => ComputeDevice.auto,
  };
  _log('START ${spec.name} maxTok=$maxTok device=${_cfg['DEVICE']}');

  final rssBefore = ProcessInfo.currentRss;
  final sw = Stopwatch()..start();
  final engine = await LlamaEngine.load(
    LlamaModel(ModelSource.path('${_cfg['BASE']}/$file')),
    params: litert
        ? const LiteRtLmModelParams(embeddingEngine: true, device: ComputeDevice.cpu, contextSize: 1024)
        : ModelParams(contextSize: 1024, batchSize: 1024, microBatchSize: 1024, device: device),
  );
  final loadMs = sw.elapsedMilliseconds;
  final rssAfterLoad = ProcessInfo.currentRss;
  String backend;
  try {
    backend = await engine.getBackendName();
  } catch (e) {
    backend = '? ($e)';
  }
  int? gpuLayers;
  try {
    gpuLayers = await engine.getResolvedGpuLayers();
  } catch (_) {}

  // Il profilo EG2 aggiunge il prefisso classification; gli altri ricevono il testo già formattato.
  final embedder = spec.eg2
      ? LlamaTextEmbedder(engine, profile: LlamaEmbeddingProfile.embeddingGemma2)
      : null;
  Future<List<double>> embed(String text) => embedder != null
      ? embedder.embed(LlamaEmbeddingText.query(text, task: LlamaEmbeddingTask.classification))
      : engine.embed(spec.format(text), normalize: true);

  // LiteRT-LM in modalità embedding non espone il tokenizer: riusa i testi troncati dal run
  // GGUF di EG2 (stesso tokenizer Gemma, stesso prefisso), che li salva in BASE.
  final textsFile = File('${_cfg['BASE']}/eg2-texts-$maxTok.json');
  late final List<String> emailTexts, labelTexts;
  var truncated = 0;
  // Oltre il context_length di addestramento llama.cpp va in GGML_ASSERT e chiude il processo
  // (e5 GGUF dichiara 511): il limite effettivo è il minimo tra i due.
  var limit = maxTok;
  if (litert) {
    final saved = jsonDecode(await textsFile.readAsString()) as Map<String, dynamic>;
    emailTexts = (saved['emails'] as List).cast<String>();
    labelTexts = (saved['labels'] as List).cast<String>();
    truncated = saved['truncated'] as int;
  } else {
    // Tronca `text` perché `format(text)` con i token speciali stia in maxTok.
    final meta = await engine.getMetadata();
    final trained = int.tryParse(meta['${meta['general.architecture']}.context_length'] ?? '');
    if (trained != null && trained < limit) limit = trained;
    final overhead = (await engine.tokenize(spec.format(''))).length;
    Future<String> truncate(String text) async {
      final tokens = await engine.tokenize(text, addSpecial: false);
      var budget = limit - overhead;
      if (tokens.length <= budget) {
        if ((await engine.tokenize(spec.format(text))).length <= limit) return text;
      }
      truncated++;
      while (true) {
        final cut = await engine.detokenize(tokens.sublist(0, math.min(budget, tokens.length)));
        final n = (await engine.tokenize(spec.format(cut))).length;
        if (n <= limit) return cut;
        budget -= n - limit;
      }
    }

    emailTexts = <String>[];
    for (final e in emails) {
      emailTexts.add(
        await truncate(
          emailText(subject: e['subject'] as String, from: e['from'] as String, body: e['body'] as String),
        ),
      );
    }
    labelTexts = <String>[];
    for (final l in labels) {
      labelTexts.add(
        await truncate(labelText(name: l['name'] as String, description: l['description'] as String)),
      );
    }
    if (spec.eg2) {
      await textsFile.writeAsString(
        jsonEncode({'emails': emailTexts, 'labels': labelTexts, 'truncated': truncated}),
      );
    }
  }

  // Il primo embed include l'eventuale caricamento pigro (LiteRT-LM) e la compilazione dei kernel.
  final firstSw = Stopwatch()..start();
  await embed(emailTexts.first);
  final firstEmbedMs = firstSw.elapsedMilliseconds;
  for (final t in emailTexts.skip(1).take(2)) {
    await embed(t);
  }
  final latencies = <double>[];
  final emailVecs = <List<double>>[];
  for (final t in emailTexts) {
    final s = Stopwatch()..start();
    emailVecs.add(await embed(t));
    latencies.add(s.elapsedMicroseconds / 1000);
  }
  final labelVecs = [for (final t in labelTexts) await embed(t)];
  final maxRss = ProcessInfo.maxRss;
  await engine.dispose();

  final platform = _cfg['PLATFORM']!;
  final suffix = !litert && device != ComputeDevice.auto ? '-${_cfg['DEVICE']}' : '';
  final stem = 'llamadart-$platform-${spec.name}$suffix-$maxTok';
  // Niente `|` nel nome: finisce in una tabella markdown.
  final prefix = spec.format('').replaceAll(' | ', ', ').trim();
  final modelDesc = '${spec.name}$suffix (${prefix.isEmpty ? 'nessun prefisso' : 'prefisso "$prefix"'})';

  Future<void> writeEmbeddings(String name, int dim) => _write(
    '$name.json',
    jsonEncode({
      'runtime': 'llamadart',
      'model': dim == 768 || !spec.eg2 ? modelDesc : '$modelDesc dim$dim',
      'maxTokens': maxTok,
      'labels': [
        for (var i = 0; i < labels.length; i++)
          {'name': labels[i]['name'], 'embedding': _trim(labelVecs[i], dim)},
      ],
      'emails': [
        for (var i = 0; i < emails.length; i++)
          {
            'id': emails[i]['id'],
            'label': emails[i]['label'],
            'lang': emails[i]['lang'],
            'embedding': _trim(emailVecs[i], dim),
          },
      ],
    }),
  );

  final dim = emailVecs.first.length;
  await writeEmbeddings(stem, dim);
  // Matryoshka: troncare a 256 e rinormalizzare è ciò che fa LlamaTextEmbedder(dimensions: 256).
  if (spec.eg2) await writeEmbeddings('$stem-dim256', 256);

  final sorted = [...latencies]..sort();
  double pct(double p) => sorted[((sorted.length - 1) * p).round()];
  const mb = 1024 * 1024;
  await _write(
    '$stem.metrics.json',
    const JsonEncoder.withIndent('  ').convert({
      'runtime': 'llamadart 0.17.5',
      'model': modelDesc,
      'modelFile': file,
      'modelBytes': File('${_cfg['BASE']}/$file').lengthSync(),
      'maxTokens': maxTok,
      'maxTokensEffective': limit,
      'dim': dim,
      'platform': platform,
      'os': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'cpus': Platform.numberOfProcessors,
      'deviceRequested': litert ? 'cpu' : _cfg['DEVICE'],
      'backend': backend,
      'gpuLayers': gpuLayers,
      'loadMs': loadMs,
      'firstEmbedMs': firstEmbedMs,
      'emailsTruncated': truncated,
      'latencyMs': {
        'p50': pct(0.5),
        'p95': pct(0.95),
        'mean': latencies.reduce((a, b) => a + b) / latencies.length,
        'min': sorted.first,
        'max': sorted.last,
      },
      'rssMb': {'beforeLoad': rssBefore / mb, 'afterLoad': rssAfterLoad / mb, 'maxAtEnd': maxRss / mb},
    }),
  );
  _log('OK $stem load=${loadMs}ms p50=${pct(0.5)} backend=$backend');
}

List<double> _trim(List<double> v, int dim) {
  if (dim == v.length) return v;
  final out = v.sublist(0, dim);
  final norm = math.sqrt(out.fold(0.0, (s, x) => s + x * x));
  return [for (final x in out) x / norm];
}

Future<void> _write(String name, String content) async {
  final dir = Directory('${_cfg['BASE']}/out')..createSync(recursive: true);
  await File('${dir.path}/$name').writeAsString(content);
}

// ignore: avoid_print
void _log(String m) => print('[spike103] $m');
