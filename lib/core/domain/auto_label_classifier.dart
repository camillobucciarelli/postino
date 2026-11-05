import 'dart:math';

/// The cosine of the closest Etichetta at least this, or no Etichetta: a floor against a broken vector.
// ponytail: inert with EmbeddingGemma-2, whose top-1 cosines on the spike #103 mail are 0.66-0.94 (#135). A floor
// against mail outside every Etichetta would differ for centroid and zero-shot; calibrate it on real mail.
const minAutoLabelCosine = 0.30;

/// The closest Etichetta at least this above the second, or no Etichetta: on the spike #103 mail with the
/// `.litertlm` (#135), precision 1.00 and coverage 0.66 for the centroid, 0.95 and 0.74 for the zero-shot.
const minAutoLabelMargin = 0.02;

/// From this many examples an Etichetta's prototype is their centroid; with fewer, its name and description.
const minAutoLabelExamples = 3;

/// The examples of an Etichetta are its newest mail, this many at most.
const maxAutoLabelExamples = 50;

/// The cosine of [a] and [b]: 0 when either is the zero vector.
double cosine(List<double> a, List<double> b) {
  var dot = 0.0;
  var na = 0.0;
  var nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return na == 0 || nb == 0 ? 0 : dot / sqrt(na * nb);
}

/// The prototype of an Etichetta from its examples: their sum, the cosine ignores the scale.
List<double> centroid(List<List<double>> examples) => [
  for (var i = 0; i < examples.first.length; i++) examples.fold(0, (s, e) => s + e[i]),
];

/// The Etichetta of [prototypes] (by id) closest to [email], when it clears [minAutoLabelCosine] and, with two or
/// more, [minAutoLabelMargin] over the second; otherwise null. At most one Etichetta.
String? pickAutoLabel(Map<String, List<double>> prototypes, List<double> email) {
  final scored = [for (final MapEntry(:key, :value) in prototypes.entries) (id: key, cos: cosine(email, value))]
    ..sort((a, b) => b.cos.compareTo(a.cos));
  if (scored.isEmpty || scored.first.cos < minAutoLabelCosine) return null;
  if (scored.length > 1 && scored[0].cos - scored[1].cos < minAutoLabelMargin) return null;
  return scored.first.id;
}
