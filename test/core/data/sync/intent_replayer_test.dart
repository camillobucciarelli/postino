import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/sync/intent_replayer.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/mail_action.dart';
import 'package:postino/core/domain/outbox_repository.dart';

import '../../../support/fake_mail_provider.dart';
import '../../../support/harness.dart';

void main() {
  late Harness h;
  late FakeMailProvider a;

  IntentReplayer replayer({required bool removed}) => IntentReplayer(
    GetIt.I<MailStore>(),
    GetIt.I<OutboxRepository>(),
    h.clock,
    h.errorLog,
    pause: (_, _) {},
    removed: (_) => removed,
  );

  setUp(() async {
    h = await Harness.create();
    a = (await h.addAccount('a'))..deliver(msg('1'));
    await GetIt.I<SyncEngine>().syncAll();
    a.goOffline();
    await GetIt.I<SyncEngine>().act('a', ['1'], const Star());
    a.goOnline();
  });

  test('an Account being removed sends nothing, and does not read as paused', () async {
    expect(await replayer(removed: true).replayActions('a', a), isFalse);
    expect(a.actionCalls, isEmpty);
  });

  test('the same queue goes out when the Account is not being removed', () async {
    expect(await replayer(removed: false).replayActions('a', a), isFalse);
    expect([for (final c in a.actionCalls) c.$2], [const Star()]);
  });
}
