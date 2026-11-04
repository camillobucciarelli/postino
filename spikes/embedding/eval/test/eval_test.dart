import 'package:embedding_eval/eval.dart';
import 'package:test/test.dart';

void main() {
  final labels = <Label>[
    (name: 'A', v: [1, 0, 0]),
    (name: 'B', v: [0, 1, 0]),
  ];
  // `odd` è etichettata A ma sta vicino a B: se il leave-one-out trovasse sé stessa, verrebbe predetta A.
  final emails = <Email>[
    (id: 'a1', label: 'A', lang: 'it', v: [1, 0.1, 0]),
    (id: 'a2', label: 'A', lang: 'en', v: [0.9, 0.2, 0]),
    (id: 'b1', label: 'B', lang: 'it', v: [0.1, 1, 0]),
    (id: 'b2', label: 'B', lang: 'en', v: [0.2, 0.9, 0]),
    (id: 'odd', label: 'A', lang: 'it', v: [0.3, 1, 0.05]),
  ];

  test('zero-shot, kNN e centroide leave-one-out', () {
    expect(zeroShot(emails[0].v, labels).label, 'A');
    expect(zeroShot(emails[4].v, labels).label, 'B');
    expect(knn(emails, 4, 1), 'B', reason: "l'email non deve trovare sé stessa");
    expect(knn(emails, 0, 3), 'A', reason: 'vicini a2(A), odd(A), b2(B): vince A');
    expect(centroid(emails, 4), 'B', reason: 'il centroide di A esclude odd');

    final s = evaluate((runtime: 'test', model: 'fake', maxTokens: 256, labels: labels, emails: emails));
    expect(s['zeroShot'], {'all': 0.8, 'en': 1.0, 'it': 2 / 3});
    expect((s['zeroShotMargin']! as List<Object?>).first, {'margin': 0.0, 'coverage': 1.0, 'precision': 0.8});
  });
}
