import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/result.dart';

String describe(Result<int> r) => switch (r) {
  Ok(:final value) => 'ok $value',
  Err(failure: UnexpectedFailure(:final error)) => 'err $error',
};

void main() {
  test('Ok carries the value', () {
    expect(describe(const Ok(42)), 'ok 42');
  });

  test('Err carries the failure', () {
    expect(describe(const Err(UnexpectedFailure('boom'))), 'err boom');
  });
}
