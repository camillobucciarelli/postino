// Revoked credentials on an IMAP Account: the real adapter and sync engine turn the refused LOGIN into an
// AuthFailure, and the sidebar shows the Account Da ricollegare.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/imap/imap_provider.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/mail_provider.dart';
import 'package:postino/core/domain/mail_sync.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../../support/harness.dart';
import '../../../support/recorded_imap_server.dart';

const _id = 'icloud:ada@icloud.com';

void main() {
  testWidgets('a refused login makes the iCloud Account Da ricollegare', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view
      ..physicalSize = const Size(950, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create();
    final server = (await tester.runAsync(
      () => RecordedImapServer.start(
        (c) => c.startsWith('LOGIN')
            ? ['NO [AUTHENTICATIONFAILED] Authentication failed']
            : basics(c, capabilities: 'IMAP4rev1 IDLE')!,
      ),
    ))!;
    await tester.runAsync(() async {
      await server.remember(h.keychain, _id);
      getIt.registerSingleton<MailProvider>(
        ImapProvider(_id, 'ada@icloud.com', h.keychain, h.clock, connect: plainConnector),
        instanceName: _id,
      );
      await getIt<MailStore>().addAccount(
        const Account(id: _id, address: 'ada@icloud.com', provider: ProviderKind.icloud, color: 0, position: 0),
      );
      await getIt<MailSync>().syncAll();
    });
    expect(server.commands.where((c) => c.startsWith('LOGIN')), isNotEmpty);
    expect((await tester.runAsync(() => getIt<MailStore>().accounts()))!.single.status, AccountStatus.daRicollegare);

    LocaleSettings.setLocaleSync(AppLocale.it);
    await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
    unawaited(Routefly.navigate(routePaths.posta.path));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.byKey(const ValueKey('account-$_id'))).label, 'ada@icloud.com, Da ricollegare');
    await tester.runAsync(server.stop);
    handle.dispose();
  });
}
