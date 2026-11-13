// Mutation test of the hand-written Dart under lib/: `mutation_test` mutates one file at a time and runs only
// that file's tests. Usage and options in docs/agents/mutation-test.md.
import 'dart:async';
import 'dart:io';

import 'report.dart';
import 'targets.dart';

const _rules = 'tool/mutation/rules.xml';

Future<void> main(List<String> args) async {
  final opts = {
    for (final a in args)
      if (RegExp(r'^--([a-z-]+)=(.*)$').firstMatch(a) case final m?) m.group(1)!: m.group(2)!,
  };
  final base = opts['base'];
  final prefix = opts['path'] ?? 'lib/';
  final budget = int.parse(opts['max-mutants'] ?? '0');
  final threshold = double.parse(opts['threshold'] ?? '0');
  final timeout = int.parse(opts['timeout'] ?? '120');
  final out = opts['out'] ?? 'build/mutation';
  final flutter = opts['flutter'] ?? 'flutter';

  final candidates = base != null
      ? await _lines('git', ['diff', '--name-only', '--diff-filter=d', '$base...HEAD', '--', 'lib'])
      : await _lines('git', ['ls-files', '--', ...prefix.split(',')]);
  final targets = candidates.where(isMutable).toList()..sort();
  if (targets.isEmpty) return _finish(out, 'Nessun file Dart mutabile da provare.\n', failed: false);

  final tests = {
    for (final t in await _lines('git', ['ls-files', '--', 'test']))
      if (t.endsWith('_test.dart')) t: File(t).readAsStringSync(),
  };
  final testsOf = {for (final t in targets) t: testsFor(t, tests)};
  final withoutTests = [
    for (final t in targets)
      if (testsOf[t]!.isEmpty) t,
  ];
  final tooManyTests = [
    for (final t in targets)
      if (testsOf[t]!.length > maxIndirectTests) '$t (${testsOf[t]!.length} test)',
  ];
  final tested = [
    for (final t in targets)
      if (testsOf[t]!.isNotEmpty && testsOf[t]!.length <= maxIndirectTests) t,
  ];

  Directory(out).createSync(recursive: true);
  final errors = <String>[];
  final redBaseline = <String>[];
  final results = <FileResult>[];

  // Dry run: lists every candidate mutant without running tests, to sample them under the budget.
  final dryInput = _input('$out/dry.xml', tested, {}, 'true', timeout);
  final dry = await (await _mutationTest(['-d', '-o', '$out/dry', dryInput])).exitCode;
  if (dry != 0 && dry != 255) return _finish(out, 'mutation_test --dry è uscito con $dry.\n', failed: true);
  final planned = File('$out/dry/mutation-test.xunit.xml').existsSync()
      ? parseXunit(File('$out/dry/mutation-test.xunit.xml').readAsStringSync())
      : <Mutant>[];
  final sample = sampleLines([for (final m in planned) (file: m.file, line: m.line)], budget);
  final sampling = sample == null
      ? null
      : '${planned.where((m) => sample[m.file]?.contains(m.line) ?? false).length} mutanti su '
            '${planned.length} candidati: una riga ogni ${(planned.length + budget - 1) ~/ budget} in ordine di file '
            'e riga, entro il tetto di $budget.';

  for (final file in tested) {
    if (!planned.any((m) => m.file == file)) continue;
    if (sample != null && !sample.containsKey(file)) continue;
    final slug = file.replaceAll('/', '_');
    final command = '$flutter test --no-pub ${testsOf[file]!.join(' ')}';
    stdout.writeln('▶ $file (${testsOf[file]!.join(', ')})');
    final lcov = '$out/$slug/lcov.info';
    final green = await _run(flutter, [
      'test',
      '--no-pub',
      '--reporter=failures-only',
      '--coverage',
      '--coverage-path',
      lcov,
      ...testsOf[file]!,
    ], Duration(seconds: timeout * 3));
    if (!green) {
      redBaseline.add(file);
      continue;
    }
    final original = File(file).readAsStringSync();
    final input = _input('$out/$slug.xml', [file], {file: ?sample?[file]}, command, timeout);
    final exit = await _guarded(file, original, await _mutationTest(['-c', lcov, '-o', '$out/$slug', input]));
    if (File(file).readAsStringSync() != original) {
      File(file).writeAsStringSync(original);
      errors.add('$file: mutante rimasto nel sorgente, ripristinato');
    }
    // 255: the quality gate of mutation_test, unused (threshold 0 in rules.xml); anything else is a crash.
    if (exit != 0 && exit != 255) {
      errors.add('$file: mutation_test è uscito con $exit');
      continue;
    }
    final report = File('$out/$slug/mutation-test.xunit.xml');
    results.add((
      file: file,
      tests: testsOf[file]!,
      mutants: report.existsSync() ? parseXunit(report.readAsStringSync()) : [],
    ));
  }

  final reached = score([for (final r in results) ...r.mutants]) ?? 100;
  final markdown = renderReport(
    results: results,
    threshold: threshold,
    withoutTests: withoutTests,
    tooManyTests: tooManyTests,
    redBaseline: redBaseline,
    errors: errors,
    sampling: sampling,
  );
  final belowThreshold = reached < threshold;
  await _finish(
    out,
    belowThreshold ? '$markdown\nPunteggio sotto la soglia.\n' : markdown,
    failed: errors.isNotEmpty || belowThreshold,
  );
}

/// Writes the input document of `mutation_test` for [files] at [path]: [lines] whitelists the sampled lines.
String _input(String path, List<String> files, Map<String, Set<int>> lines, String command, int timeout) {
  String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;');
  final xml = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n<mutations version="1.2">\n<files>\n');
  for (final f in files) {
    xml.write('<file>${esc(f)}');
    for (final l in (lines[f] ?? <int>{}).toList()..sort()) {
      xml.write('<lines begin="$l" end="$l"/>');
    }
    xml.write('</file>\n');
  }
  xml.write(
    '</files>\n<commands>\n<command group="test" expected-return="0" timeout="$timeout">${esc(command)}</command>\n'
    '</commands>\n</mutations>\n',
  );
  File(path).writeAsStringSync(xml.toString());
  return path;
}

Future<Process> _mutationTest(List<String> args) => Process.start(Platform.resolvedExecutable, [
  'run',
  'mutation_test',
  '--exclude-strings',
  '--no-builtin',
  '-r',
  _rules,
  '-f',
  'xunit',
  '-q',
  ...args,
], mode: ProcessStartMode.inheritStdio);

/// Waits for [child], which may leave a mutant of [file] on disk: on SIGINT or SIGTERM it stops the child,
/// puts [original] back and exits.
Future<int> _guarded(String file, String original, Process child) async {
  final subscriptions = [
    for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm])
      signal.watch().listen((_) async {
        child.kill(ProcessSignal.sigint);
        await child.exitCode.timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            child.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
        File(file).writeAsStringSync(original);
        stderr.writeln('Interrotto: $file ripristinato.');
        exit(130);
      }),
  ];
  try {
    return await child.exitCode;
  } finally {
    for (final s in subscriptions) {
      await s.cancel();
    }
  }
}

/// Whether [executable] exits with 0 within [limit].
Future<bool> _run(String executable, List<String> args, Duration limit) async {
  final p = await Process.start(executable, args, mode: ProcessStartMode.inheritStdio);
  try {
    return await p.exitCode.timeout(limit) == 0;
  } on TimeoutException {
    p.kill();
    return false;
  }
}

Future<List<String>> _lines(String executable, List<String> args) async {
  final r = await Process.run(executable, args);
  if (r.exitCode != 0) throw ProcessException(executable, args, '${r.stderr}', r.exitCode);
  return '${r.stdout}'.split('\n').where((l) => l.isNotEmpty).toList();
}

Future<void> _finish(String out, String markdown, {required bool failed}) async {
  Directory(out).createSync(recursive: true);
  File('$out/report.md').writeAsStringSync(markdown);
  stdout.write(markdown);
  final summary = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summary != null && summary.isNotEmpty) File(summary).writeAsStringSync(markdown, mode: FileMode.append);
  exitCode = failed ? 1 : 0;
}
