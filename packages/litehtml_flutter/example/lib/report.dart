import 'bench.dart';

/// Tabelle Markdown delle misure: il primo giro (freddo) a parte, mediana e massimo sui successivi.
String report(List<BenchResult> results, {required String mode}) {
  final b = StringBuffer()
    ..writeln(
      'Modalità: $mode. Giri per caso: ${results.first.runs.length} (il primo è freddo, mediana e max sugli altri).',
    )
    ..writeln()
    ..writeln(
      '| Email | Larghezza | Altezza | Creazione freddo / mediana (ms) | Layout freddo / mediana / max (ms) '
      '| Draw freddo / mediana / max (ms) | Totale freddo / mediana (ms) | di cui `text_width` in Dart freddo / mediana (ms) '
      '| Stringhe misurate |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|---|');
  for (final r in results) {
    final warm = r.runs.skip(1).toList();
    String col(int Function(Timing) f) =>
        '${_ms(f(r.runs.first))} / ${_ms(_median(warm.map(f)))} / ${_ms(warm.map(f).reduce((a, c) => a > c ? a : c))}';
    b.writeln(
      '| ${r.name} | ${r.width.round()} | ${r.height.round()} '
      '| ${_ms(r.runs.first.createUs)} / ${_ms(_median(warm.map((t) => t.createUs)))} '
      '| ${col((t) => t.layoutUs)} | ${col((t) => t.drawUs)} '
      '| ${_ms(_total(r.runs.first))} / ${_ms(_median(warm.map(_total)))} '
      '| ${_ms(r.runs.first.textWidthUs)} / ${_ms(_median(warm.map((t) => t.textWidthUs)))} '
      '| ${r.measuredStrings} |',
    );
  }
  b
    ..writeln()
    ..writeln('Callback FFI (C++→Dart) per fase, uguali a ogni giro:')
    ..writeln()
    ..writeln('| Email | Larghezza | Fase | Callback |')
    ..writeln('|---|---|---|---|');
  for (final r in results) {
    for (final phase in r.calls.entries) {
      final entries = phase.value.entries.toList()..sort((a, c) => a.key.compareTo(c.key));
      final total = entries.fold(0, (s, e) => s + e.value);
      b.writeln(
        '| ${r.name} | ${r.width.round()} | ${phase.key} '
        '| ${entries.map((e) => '${e.key} ${e.value}').join(', ')}${entries.isEmpty ? '—' : ' (tot. $total)'} |',
      );
    }
  }
  return b.toString();
}

int _total(Timing t) => t.createUs + t.layoutUs + t.drawUs;

int _median(Iterable<int> values) {
  final sorted = values.toList()..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) ~/ 2;
}

String _ms(int us) => (us / 1000).toStringAsFixed(1);
