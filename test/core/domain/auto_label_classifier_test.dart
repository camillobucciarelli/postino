// Etichettatura automatica (#109): prototipi, coseno, soglia assoluta e margine.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/auto_label_classifier.dart';

void main() {
  test('the cosine ignores the scale and is zero for a null vector', () {
    expect(cosine([1, 0], [3, 0]), closeTo(1, 1e-9));
    expect(cosine([1, 0], [0, 2]), closeTo(0, 1e-9));
    expect(cosine([0, 0], [1, 0]), 0);
  });

  test('the centroid is the sum of the examples', () {
    expect(
      centroid([
        [1, 0],
        [0, 1],
        [1, 1],
      ]),
      [2, 2],
    );
  });

  test('the closest Etichetta wins when it clears the threshold and the margin', () {
    expect(
      pickAutoLabel(
        {
          'Viaggi': [1, 0],
          'Fatture': [0, 1],
        },
        [0.9, 0.1],
      ),
      'Viaggi',
    );
  });

  test('below the absolute threshold no Etichetta, a single one too', () {
    // cos ≈ 0.2 < 0.30.
    expect(
      pickAutoLabel(
        {
          'Viaggi': [1, 0],
        },
        [0.2, 0.98],
      ),
      isNull,
    );
    expect(
      pickAutoLabel(
        {
          'Viaggi': [1, 0],
        },
        [0.5, 0.5],
      ),
      'Viaggi',
    );
  });

  test('two Etichette closer than the margin: none of them', () {
    // Both ≈ 0.707: above the threshold, but the margin is zero.
    expect(
      pickAutoLabel(
        {
          'Viaggi': [1, 0],
          'Fatture': [0, 1],
        },
        [1, 1],
      ),
      isNull,
    );
  });

  test('no Etichetta to pick from: none', () {
    expect(pickAutoLabel({}, [1, 0]), isNull);
  });
}
