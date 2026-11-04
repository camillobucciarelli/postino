// Coseno tra gli embedding delle stesse email in due JSON di scambio (es. Q8_0 vs BF16).
// Uso: dart run tool/cosine.dart a.json b.json
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

void main(List<String> args) {
  Map<String, List<double>> load(String p) => {
    for (final e in (jsonDecode(File(p).readAsStringSync())['emails'] as List))
      e['id'] as String: (e['embedding'] as List).cast<num>().map((x) => x.toDouble()).toList(),
  };
  final a = load(args[0]), b = load(args[1]);
  final cos = [
    for (final id in a.keys)
      () {
        final x = a[id]!, y = b[id]!;
        var d = 0.0, nx = 0.0, ny = 0.0;
        for (var i = 0; i < x.length; i++) {
          d += x[i] * y[i];
          nx += x[i] * x[i];
          ny += y[i] * y[i];
        }
        return d / math.sqrt(nx * ny);
      }(),
  ];
  final mean = cos.reduce((s, c) => s + c) / cos.length;
  // ignore: avoid_print
  print('n=${cos.length} mean=${mean.toStringAsFixed(4)} min=${cos.reduce(math.min).toStringAsFixed(4)}');
}
