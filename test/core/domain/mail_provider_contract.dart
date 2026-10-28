// Contract suite of the Provider adapter (ADR 0002): real adapters pass the same cases.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/core/domain/result.dart';

import '../../support/fake_mail_provider.dart';

/// What the suite needs from an adapter under test, beyond [MailProvider] itself.
abstract class ContractHarness {
  MailProvider get provider;

  /// A message arrives in the mailbox "elsewhere".
  void deliver(Message m);

  /// A message is deleted from the mailbox "elsewhere".
  void removeRemotely(String id);
  void goOffline();
  void breakAuth();
}

class FakeHarness implements ContractHarness {
  final fake = FakeMailProvider();
  @override
  MailProvider get provider => fake;
  @override
  void deliver(Message m) => fake.deliver(m);
  @override
  void removeRemotely(String id) => fake.removeRemotely(id);
  @override
  void goOffline() => fake.goOffline();
  @override
  void breakAuth() => fake.breakAuth();
}

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got $failure'),
};

void mailProviderContract(String name, ContractHarness Function() create) {
  group('MailProvider contract: $name', () {
    late ContractHarness h;
    setUp(() => h = create());

    test('initial sync returns the mailbox messages and a cursor', () async {
      h.deliver(msg('a'));
      h.deliver(msg('b'));
      final batch = _ok(await h.provider.initialSync());
      expect(batch.messages.map((m) => m.id), unorderedEquals(['a', 'b']));
      expect(batch.cursor, isNotEmpty);
    });

    test('incremental sync from a cursor returns only what changed', () async {
      h.deliver(msg('a'));
      final first = _ok(await h.provider.initialSync());
      h.deliver(msg('b'));
      final next = _ok(await h.provider.incrementalSync(first.cursor));
      expect(next.messages.map((m) => m.id), ['b']);
      final again = _ok(await h.provider.incrementalSync(next.cursor));
      expect(again.messages, isEmpty);
    });

    test(
      'a message removed remotely shows up as removed and moves the cursor',
      () async {
        h.deliver(msg('a'));
        final first = _ok(await h.provider.initialSync());
        h.removeRemotely('a');
        final next = _ok(await h.provider.incrementalSync(first.cursor));
        expect(next.removedMessageIds, ['a']);
        expect(next.cursor, isNot(first.cursor));
      },
    );

    test('a refused login is an AuthFailure', () async {
      h.breakAuth();
      for (final r in [
        await h.provider.refreshAuth(),
        await h.provider.initialSync(),
        await h.provider.incrementalSync('0'),
      ]) {
        expect(
          r,
          isA<Err>().having((e) => e.failure, 'failure', isA<AuthFailure>()),
        );
      }
    });

    test('no network is an OfflineFailure', () async {
      h.goOffline();
      final r = await h.provider.initialSync();
      expect(
        r,
        isA<Err>().having((e) => e.failure, 'failure', isA<OfflineFailure>()),
      );
    });

    test(
      'fetches a body on request and NotFound for an unknown message',
      () async {
        h.deliver(msg('a'));
        expect(_ok(await h.provider.fetchBody('a')), isNotEmpty);
        final r = await h.provider.fetchBody('zzz');
        expect(
          r,
          isA<Err>().having(
            (e) => e.failure,
            'failure',
            isA<NotFoundFailure>(),
          ),
        );
      },
    );

    test('an unknown attachment is NotFound', () async {
      h.deliver(msg('a'));
      final r = await h.provider.fetchAttachment('a', 'nope');
      expect(
        r,
        isA<Err>().having((e) => e.failure, 'failure', isA<NotFoundFailure>()),
      );
    });

    test(
      'sends and keeps drafts; deleting a missing draft is NotFound',
      () async {
        const m = OutgoingMessage(
          messageId: '<x@example.com>',
          to: ['b@example.com'],
          subject: 's',
          body: 'b',
        );
        _ok(await h.provider.send(m));
        _ok(await h.provider.saveDraft(m));
        _ok(await h.provider.deleteDraft(m.messageId));
        final r = await h.provider.deleteDraft(m.messageId);
        expect(
          r,
          isA<Err>().having(
            (e) => e.failure,
            'failure',
            isA<NotFoundFailure>(),
          ),
        );
      },
    );
  });
}
