import 'package:flutter_test/flutter_test.dart';

/// Value equality (#94): [make] builds a fresh, equal value on each call (collections included);
/// each of [others] differs from it in one field, so a field missing from `props` fails here.
void expectValueEquality(Object Function() make, List<Object> others) {
  expect(make(), make());
  expect(make().hashCode, make().hashCode);
  for (final (i, other) in others.indexed) {
    expect(make(), isNot(other), reason: 'variant $i');
  }
}
