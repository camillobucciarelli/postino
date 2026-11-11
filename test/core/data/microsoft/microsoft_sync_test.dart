// A Microsoft Account on the real sync engine and database, its adapter on the simulated Graph mailbox: polling
// only (no change signal in v1, ADR 0008), folder moves, and revoked credentials.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/sync_engine.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/message.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../../support/fake_mail_provider.dart' show msg;
import '../../../support/graph_harness.dart';
import '../../../support/graph_recorded.dart';
import '../../../support/harness.dart';

const _account = Account(
  id: graphAccount,
  address: 'ada@outlook.com',
  provider: ProviderKind.microsoft,
  color: 0,
  position: 0,
);

Future<(Harness, GraphHarness)> _start() async {
  final h = await Harness.create();
  final graph = GraphHarness();
  getIt.registerSingleton<MailProvider>(graph.provider, instanceName: graphAccount);
  await getIt<MailStore>().addAccount(_account);
  return (h, graph);
}

Future<List<String>?> _labelsOf(String id) async =>
    (await getIt<MailStore>().watchMessage(graphAccount, id).first)?.labelIds;

void main() {
  test('no change signal: new mail and a move elsewhere arrive with the poll, one message in its new folder', () async {
    final (h, graph) = await _start();
    final engine = getIt<SyncEngine>();
    graph.deliver(msg('a'));
    await engine.syncAll();
    engine.start();
    addTearDown(engine.stop);
    await pumpEventQueue();

    graph
      ..deliver(msg('b'))
      ..deliver(msg('a', labelIds: [graph.viaggiId]));
    await pumpEventQueue();
    expect(await getIt<MailStore>().messageIds(graphAccount), ['a'], reason: 'nothing before the poll');

    h.clock.advance(pollEvery);
    await pumpEventQueue(times: 50);
    expect(await getIt<MailStore>().messageIds(graphAccount), unorderedEquals(['a', 'b']));
    expect(await _labelsOf('a'), [graph.viaggiId]);
    expect(await _labelsOf('b'), [inboxLabelId]);
    expect(await getIt<MailStore>().accounts(), [
      isA<Account>().having((a) => a.status, 'status', AccountStatus.attivo),
    ]);
  });

  testWidgets('revoked credentials make the Microsoft Account Da ricollegare', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view
      ..physicalSize = const Size(950, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final (_, graph) = await _start();
      graph.breakAuth();
      await getIt<SyncEngine>().syncAll();
      expect(graph.requests.where((r) => r.url.host == tokenHost), isNotEmpty);
    });
    expect((await tester.runAsync(() => getIt<MailStore>().accounts()))!.single.status, AccountStatus.daRicollegare);

    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    unawaited(Routefly.navigate(routePaths.posta.path));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byKey(const ValueKey('account-$graphAccount'))).label,
      'ada@outlook.com, Da ricollegare',
    );
    handle.dispose();
  });
}
