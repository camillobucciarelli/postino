import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/result.dart';

String describe(Result<int> r) => switch (r) {
  Ok(:final value) => 'ok $value',
  Err(failure: UnexpectedFailure(:final error)) => 'err $error',
  Err(failure: AuthFailure()) => 'auth',
  Err(failure: OfflineFailure()) => 'offline',
  Err(failure: NotFoundFailure()) => 'notfound',
  Err(failure: RateLimitFailure()) => 'ratelimit',
  Err(failure: ConfigurationFailure(:final setting)) => 'config $setting',
  Err(failure: CancelledFailure()) => 'cancelled',
  Err(failure: DraftWithAttachmentsFailure()) => 'draft-attachments',
  Err(failure: MissingPermissionFailure()) => 'missing-permission',
  Err(failure: WrongAccountFailure(:final expected)) =>
    'wrong-account $expected',
};

void main() {
  test('Ok carries the value', () {
    expect(describe(const Ok(42)), 'ok 42');
  });

  test('Err carries the failure', () {
    expect(describe(const Err(UnexpectedFailure('boom'))), 'err boom');
  });
  test('every Provider failure is distinguishable', () {
    expect(describe(const Err(AuthFailure())), 'auth');
    expect(describe(const Err(OfflineFailure())), 'offline');
    expect(describe(const Err(NotFoundFailure())), 'notfound');
    expect(describe(const Err(RateLimitFailure())), 'ratelimit');
    expect(describe(const Err(ConfigurationFailure('X'))), 'config X');
    expect(describe(const Err(CancelledFailure())), 'cancelled');
  });
}
