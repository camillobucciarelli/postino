/// Metriche di accuratezza per un run di embedding (formato di scambio nel README).
library;

import 'dart:math' as math;

typedef Vec = List<double>;
typedef Email = ({String id, String label, String lang, Vec v});
typedef Label = ({String name, Vec v});
typedef Run = ({String runtime, String model, int maxTokens, List<Label> labels, List<Email> emails});

/// Soglie di margine (top-1 meno top-2) per lo zero-shot con astensione.
const zeroShotMargins = [0.0, 0.02, 0.05];

Run parseRun(Map<String, Object?> json) {
  Vec vec(Object? raw) => [for (final x in raw! as List<Object?>) (x! as num).toDouble()];
  Map<String, Object?> obj(Object? raw) => raw! as Map<String, Object?>;
  return (
    runtime: json['runtime']! as String,
    model: json['model']! as String,
    maxTokens: json['maxTokens']! as int,
    labels: [
      for (final l in (json['labels']! as List<Object?>).map(obj)) (name: l['name']! as String, v: vec(l['embedding'])),
    ],
    emails: [
      for (final e in (json['emails']! as List<Object?>).map(obj))
        (id: e['id']! as String, label: e['label']! as String, lang: e['lang']! as String, v: vec(e['embedding'])),
    ],
  );
}

double cosine(Vec a, Vec b) {
  if (a.length != b.length) throw ArgumentError('Dimensioni diverse: ${a.length} vs ${b.length}');
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return dot / (math.sqrt(na) * math.sqrt(nb));
}

/// Etichetta con coseno massimo e margine sulla seconda.
({String label, double margin}) zeroShot(Vec email, List<Label> labels) {
  final scored = [for (final l in labels) (name: l.name, s: cosine(email, l.v))]..sort((a, b) => b.s.compareTo(a.s));
  return (label: scored.first.name, margin: scored.length > 1 ? scored[0].s - scored[1].s : double.infinity);
}

/// kNN leave-one-out: i k vicini di `emails[i]` escluso sé stesso, voto pesato per coseno.
String knn(List<Email> emails, int i, int k) {
  final neighbours = [
    for (var j = 0; j < emails.length; j++)
      if (j != i) (label: emails[j].label, s: cosine(emails[i].v, emails[j].v)),
  ]..sort((a, b) => b.s.compareTo(a.s));
  final votes = <String, double>{};
  for (final n in neighbours.take(k)) {
    votes[n.label] = (votes[n.label] ?? 0) + n.s;
  }
  return _argmax(votes);
}

/// Centroide leave-one-out: media degli embedding per Etichetta escluso `emails[i]`.
String centroid(List<Email> emails, int i) {
  final sums = <String, Vec>{};
  for (var j = 0; j < emails.length; j++) {
    if (j == i) continue;
    final sum = sums.putIfAbsent(emails[j].label, () => List.filled(emails[j].v.length, 0));
    for (var d = 0; d < sum.length; d++) {
      sum[d] += emails[j].v[d];
    }
  }
  // ponytail: la media non serve, il coseno ignora la scala della somma.
  return _argmax({for (final e in sums.entries) e.key: cosine(emails[i].v, e.value)});
}

String _argmax(Map<String, double> scores) => scores.entries.reduce((a, b) => b.value > a.value ? b : a).key;

/// Riepilogo serializzabile in JSON. Le accuratezze sono per `all` e per ogni lingua.
Map<String, Object?> evaluate(Run run) {
  final emails = run.emails;
  final langs = {for (final e in emails) e.lang}.toList()..sort();

  Map<String, double> accuracy(List<String> predicted) {
    double acc(bool Function(Email) keep) {
      var n = 0, ok = 0;
      for (var i = 0; i < emails.length; i++) {
        if (!keep(emails[i])) continue;
        n++;
        if (predicted[i] == emails[i].label) ok++;
      }
      return n == 0 ? 0 : ok / n;
    }

    return {'all': acc((_) => true), for (final l in langs) l: acc((e) => e.lang == l)};
  }

  final zs = [for (final e in emails) zeroShot(e.v, run.labels)];
  return {
    'runtime': run.runtime,
    'model': run.model,
    'maxTokens': run.maxTokens,
    'dim': emails.isEmpty ? 0 : emails.first.v.length,
    'n': emails.length,
    'zeroShot': accuracy([for (final z in zs) z.label]),
    'knn3': accuracy([for (var i = 0; i < emails.length; i++) knn(emails, i, 3)]),
    'knn5': accuracy([for (var i = 0; i < emails.length; i++) knn(emails, i, 5)]),
    'centroid': accuracy([for (var i = 0; i < emails.length; i++) centroid(emails, i)]),
    'zeroShotMargin': [
      for (final m in zeroShotMargins)
        () {
          final covered = [
            for (var i = 0; i < emails.length; i++)
              if (zs[i].margin >= m) zs[i].label == emails[i].label,
          ];
          return {
            'margin': m,
            'coverage': emails.isEmpty ? 0.0 : covered.length / emails.length,
            'precision': covered.isEmpty ? null : covered.where((ok) => ok).length / covered.length,
          };
        }(),
    ],
  };
}
