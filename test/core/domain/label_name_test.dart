import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/label_name.dart';

void main() {
  const existing = ['Fatture', 'Progetti', 'Progetti/Postino'];

  test('a new name is valid, nested too', () {
    expect(labelNameError('Viaggi', existing), isNull);
    expect(labelNameError('Progetti/Casa', existing), isNull);
    expect(labelNameError('  Viaggi  ', existing), isNull);
  });

  test('an empty name is refused', () {
    expect(labelNameError('', existing), LabelNameError.empty);
    expect(labelNameError('   ', existing), LabelNameError.empty);
  });

  test('an existing name is refused, ignoring case and spaces', () {
    expect(labelNameError('fatture', existing), LabelNameError.duplicate);
    expect(labelNameError(' PROGETTI/postino ', existing), LabelNameError.duplicate);
  });

  test('an empty level is refused', () {
    for (final n in ['Progetti/', '/Postino', 'Progetti//Postino', 'Progetti/ /Postino']) {
      expect(labelNameError(n, existing), LabelNameError.emptyLevel, reason: n);
    }
  });
}
