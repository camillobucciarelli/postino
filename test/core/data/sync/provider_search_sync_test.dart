// The search on the Provider through the sync engine (#207): what it stores, and what it does on a failure.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/search_query.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/harness.dart';

void main() {
  late Harness h;
  late FakeMailProvider a;
  const fattura = SearchQuery(terms: ['fattura']);
  SyncEngine engine() => GetIt.I<SyncEngine>();

  setUp(() async {
    h = await Harness.create();
    a = (await h.addAccount('a'))
      ..deliver(msg('1', subject: 'Fattura recente', date: DateTime.utc(2026, 10, 20)))
      ..deliverOutsideWindow(msg('old', subject: 'Fattura vecchia', date: DateTime.utc(2026, 4, 10)));
    await engine().syncAll();
  });

  test('an old message found is stored like any other, with no notification and no Etichettatura', () async {
    final page = switch (await engine().search('a', fattura)) {
      Ok(:final value) => value,
      Err(:final failure) => fail('$failure'),
    };
    expect(page.messages.map((m) => m.id), ['old'], reason: 'the stored one is not fetched again');
    expect(page.conversationIds, {'t-1', 't-old'});
    final inbox = await GetIt.I<InboxRepository>().watchUnifiedInbox().first;
    expect(inbox.map((e) => e.message.id), containsAll(['1', 'old']), reason: 'a normal message, in the lists too');
    expect(h.notifications.shown, isEmpty);

    // The next sync knows it: still nothing to notify.
    a.deliver(msg('2', subject: 'Nuova'));
    await engine().syncAll();
    expect(h.notifications.shown.map((n) => n.subject), ['Nuova']);
  });

  test('an AuthFailure makes the Account Da ricollegare, which is not asked again', () async {
    a.breakAuth();
    expect(await engine().search('a', fattura), isA<Err<Object?>>());
    final [account] = await GetIt.I<MailStore>().accounts();
    expect(account.status, AccountStatus.daRicollegare);

    a.restoreAuth();
    final calls = a.searchCalls.length;
    expect(
      await engine().search('a', fattura),
      isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<AuthFailure>()),
    );
    expect(a.searchCalls, hasLength(calls));
  });

  test('a rate limit pauses the Account: the next search does not reach the Provider', () async {
    a.rateLimit(retryAfter: h.clock.now().add(const Duration(minutes: 1)));
    expect(await engine().search('a', fattura), isA<Err<Object?>>());
    a.rateLimit(on: false);
    final calls = a.searchCalls.length;
    expect(
      await engine().search('a', fattura),
      isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<RateLimitFailure>()),
    );
    expect(a.searchCalls, hasLength(calls));
  });

  test('a recent message found is left to the sync, which notifies it and runs the Etichettatura', () async {
    a.deliver(msg('r', subject: 'Fattura nuova', date: h.clock.now()), signal: false);
    final page = switch (await engine().search('a', fattura)) {
      Ok(:final value) => value,
      Err(:final failure) => fail('$failure'),
    };
    expect(page.conversationIds, contains('t-r'));
    expect(await GetIt.I<MailStore>().messageIds('a'), isNot(contains('r')));
    expect(engine().autoLabeling, isEmpty, reason: 'a search runs no Etichettatura automatica');

    await engine().syncAll();
    expect(h.notifications.shown.map((n) => n.subject), ['Fattura nuova']);
    expect(engine().autoLabeling, contains('a'), reason: 'the sync labels what it brings');
  });

  test('a search queued behind a sync that makes the Account Da ricollegare does not reach the Provider', () async {
    final syncing = a.hold = Completer<void>();
    a.breakAuth();
    final sync = engine().syncAll();
    await pumpEventQueue();
    final search = engine().search('a', fattura);
    await pumpEventQueue();
    a.hold = null;
    syncing.complete();
    await sync;
    expect(await search, isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<AuthFailure>()));
    expect(a.searchCalls, isEmpty);
  });

  test('a search queued behind a sync that the Provider pauses does not reach the Provider', () async {
    final syncing = a.hold = Completer<void>();
    a.rateLimit(retryAfter: h.clock.now().add(const Duration(minutes: 1)));
    final sync = engine().syncAll();
    await pumpEventQueue();
    final search = engine().search('a', fattura);
    await pumpEventQueue();
    a.hold = null;
    syncing.complete();
    await sync;
    expect(await search, isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<RateLimitFailure>()));
    expect(a.searchCalls, isEmpty);
  });

  test('an Account removed while its search runs gets nothing written', () async {
    final held = a.holdSearch = Completer<void>();
    final search = engine().search('a', fattura);
    await pumpEventQueue();
    final removal = engine().removeAccount('a', () async {});
    held.complete();
    expect(await search, isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<NotFoundFailure>()));
    await removal;
    expect(await GetIt.I<MailStore>().messageIds('a'), isNot(contains('old')));
  });

  test('an Account gone is NotFound', () async {
    expect(
      await engine().search('zzz', fattura),
      isA<Err<Object?>>().having((e) => e.failure, 'failure', isA<NotFoundFailure>()),
    );
  });
}
