// Etichette automatiche (#107): the JSON voce of the Impostazioni di Postino, readable whatever wrote it.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/auto_labels_json.dart';

void main() {
  test('round trip keeps the switch and the description', () {
    final labels = {
      'L1': (automatic: true, description: 'Fatture dei fornitori', activatedAt: 1793750400000),
      'L2': (automatic: true, description: null, activatedAt: null),
      'L3': (automatic: false, description: 'tenuta per dopo', activatedAt: null),
    };
    expect(decodeAutoLabels(encodeAutoLabels(labels)), labels);
  });

  test('a file without the voce, or malformed, reads as no Etichetta automatica', () {
    for (final json in [null, '', 'not json', '[]', '"x"', '{"L1": 3}']) {
      expect(decodeAutoLabels(json), isEmpty, reason: '$json');
    }
  });

  test('missing fields read as off and no description; unknown fields are ignored', () {
    expect(decodeAutoLabels('{"L1": {}, "L2": {"description": "  "}, "L3": {"automatic": true, "colore": 4}}'), {
      'L1': (automatic: false, description: null, activatedAt: null),
      'L2': (automatic: false, description: null, activatedAt: null),
      'L3': (automatic: true, description: null, activatedAt: null),
    });
  });

  test('a missing or invalid activation reads as none', () {
    expect(decodeAutoLabels('{"L1": {"automatic": true, "activatedAt": "ieri"}, "L2": {"activatedAt": 1.5}}'), {
      'L1': (automatic: true, description: null, activatedAt: null),
      'L2': (automatic: false, description: null, activatedAt: null),
    });
  });

  test('an Etichetta off and without description is not written; nothing left writes null', () {
    expect(encodeAutoLabels({'L1': (automatic: false, description: null, activatedAt: null)}), isNull);
    expect(encodeAutoLabels({}), isNull);
    expect(
      encodeAutoLabels({
        'L1': (automatic: true, description: null, activatedAt: 7),
        'L2': (automatic: false, description: null, activatedAt: null),
      }),
      '{"L1":{"automatic":true,"activatedAt":7}}',
    );
  });
}
