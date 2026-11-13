// The send limit is the Provider's of the Account (#183): the same message passes for one and is refused for another.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/send_limit.dart';

import '../../support/harness.dart';

OutgoingMessage _message(int bytes) => OutgoingMessage(
  messageId: '<x@example.com>',
  from: 'a@example.com',
  to: const ['b@example.com'],
  subject: 's',
  body: '<p>${'x' * bytes}</p>',
);

Matcher _refusedAt(int limit) => isA<Err<DateTime>>().having(
  (e) => e.failure,
  'failure',
  isA<SizeLimitFailure>().having((f) => f.limitBytes, 'limitBytes', limit),
);

void main() {
  late SyncEngine engine;
  const fourMb = 4 * 1024 * 1024;

  setUp(() async {
    final h = await Harness.create();
    await h.addAccount('g');
    await h.addAccount('m', provider: ProviderKind.microsoft);
    await h.addAccount('i', provider: ProviderKind.imap);
    engine = GetIt.I<SyncEngine>();
    await engine.syncAll();
  });

  test('the limits come from one place: Gmail 35 MB, Microsoft 3 MB, IMAP the server\'s SIZE', () {
    expect(sendLimitBytes(ProviderKind.gmail), 35 * 1024 * 1024);
    expect(sendLimitBytes(ProviderKind.microsoft), 3 * 1024 * 1024);
    expect(sendLimitBytes(ProviderKind.imap), isNull);
    expect(sendLimitBytes(ProviderKind.icloud), isNull);
  });

  test('a 4 MB message passes for a Gmail Account and for an IMAP one, and is refused for a Microsoft one', () async {
    expect(await engine.send('g', _message(fourMb)), isA<Ok<DateTime>>());
    expect(await engine.send('i', _message(fourMb)), isA<Ok<DateTime>>());
    expect(await engine.send('m', _message(fourMb)), _refusedAt(microsoftSendLimitBytes));
  });

  test('a message well under the Microsoft limit passes; a message over the Gmail limit is still refused', () async {
    expect(await engine.send('m', _message(microsoftSendLimitBytes ~/ 3)), isA<Ok<DateTime>>());
    expect(await engine.send('g', _message(gmailSendLimitBytes + 1)), _refusedAt(gmailSendLimitBytes));
  });
}
