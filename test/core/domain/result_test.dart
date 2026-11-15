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
  Err(failure: DraftReplyFailure()) => 'draft-reply',
  Err(failure: MissingPermissionFailure()) => 'missing-permission',
  Err(failure: WrongAccountFailure(:final expected)) => 'wrong-account $expected',
  Err(failure: SizeLimitFailure(:final limitBytes)) => 'size $limitBytes',
  Err(failure: RejectedFailure(:final reason)) => 'rejected $reason',
  Err(failure: IntegrityFailure()) => 'integrity',
  Err(failure: DriveScopeFailure()) => 'drive-scope',
  Err(failure: ServerNotFoundFailure()) => 'server-not-found',
  Err(failure: AlreadyConnectedFailure()) => 'already-connected',
  Err(failure: UseGmailFailure()) => 'use-gmail',
  Err(failure: UseMicrosoftFailure()) => 'use-microsoft',
  Err(failure: AdminConsentFailure()) => 'admin-consent',
  Err(failure: OrganizationPolicyFailure()) => 'organization-policy',
  Err(failure: SyncNotPairedFailure()) => 'sync-not-paired',
  Err(failure: SyncKeyInvalidFailure()) => 'sync-key-invalid',
  Err(failure: PairingCodeFailure()) => 'pairing-code',
  Err(failure: NothingToPairFailure()) => 'nothing-to-pair',
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
    expect(describe(const Err(SizeLimitFailure(7))), 'size 7');
    expect(describe(const Err(RejectedFailure('x'))), 'rejected x');
    expect(describe(const Err(IntegrityFailure())), 'integrity');
    expect(describe(const Err(ServerNotFoundFailure())), 'server-not-found');
    expect(describe(const Err(AlreadyConnectedFailure())), 'already-connected');
    expect(describe(const Err(UseGmailFailure())), 'use-gmail');
    expect(describe(const Err(UseMicrosoftFailure())), 'use-microsoft');
    expect(describe(const Err(AdminConsentFailure())), 'admin-consent');
    expect(describe(const Err(OrganizationPolicyFailure())), 'organization-policy');
  });
}
