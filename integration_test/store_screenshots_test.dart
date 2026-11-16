// Screenshot per App Store Connect (#326): non è un test, guida l'app vera sul simulatore fino alle cinque schermate
// e a ogni schermata stampa `SHOT <nome>` e aspetta, perché tool/store_screenshots/shots.sh la catturi con simctl.
// Serve il server di posta finto di tool/store_screenshots/server.sh; vedi docs/store/screenshot.md.
// Gira solo con --dart-define=STORE_SHOTS=it (o en): altrimenti è saltato.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:postino/app/posta/posta_routes.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/accounts_repository.dart';
import 'package:postino/core/domain/mail_servers.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/write_fab.dart';
import 'package:postino/main.dart' as app;
import 'package:routefly/routefly.dart';

const _lang = String.fromEnvironment('STORE_SHOTS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  // Niente nastro «DEBUG» negli screenshot: il driver gira per forza in debug.
  WidgetsApp.debugAllowBannerOverride = false;

  testWidgets('store screenshots', (tester) async {
    const it = _lang == 'it';
    Future<void> wait(int seconds) async {
      for (var i = 0; i < seconds * 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shot(String name) async {
      await wait(3);
      debugPrint('SHOT $name');
      await wait(4); // il tempo della cattura
    }

    await app.main();
    await wait(3);
    const servers = ServerSettings(
      imap: MailServer(host: 'localhost', port: 3993, security: ServerSecurity.ssl),
      smtp: MailServer(host: 'localhost', port: 3465, security: ServerSecurity.ssl),
    );
    final accounts = GetIt.I<AccountsRepository>();
    // Solo su un'installazione vuota: mai accanto agli Account veri di qualcuno.
    expect(await accounts.watchAccounts().first, isEmpty, reason: 'Postino ha già degli Account su questo dispositivo');
    for (final address in ['demo@example.com', 'demo@example.org']) {
      // ponytail: tre tentativi, perché su un Mac carico il server locale a volte va in timeout.
      Result<Account>? connected;
      for (var i = 0; i < 3 && connected is! Ok<Account>; i++) {
        if (i > 0) await wait(5);
        connected = await accounts.connectWithPassword(address, 'demo-pass', servers: servers);
      }
      expect(connected, isA<Ok<Account>>(), reason: '$address non si collega al server finto');
    }
    unawaited(Routefly.navigate(app.routePaths.posta.path));
    await wait(15); // la prima sync

    final later = find.text(it ? 'Non ora' : 'Not now');
    if (later.evaluate().isNotEmpty) await tester.tap(later.first); // il permesso delle notifiche
    // iPad: le tre colonne, con la barra laterale aperta e una Conversazione accanto alla lista.
    final tablet = tester.view.physicalSize.shortestSide / tester.view.devicePixelRatio >= 600;
    final aurora = find.text(it ? 'Revisione del progetto Aurora' : 'Project Aurora review');
    if (tablet) {
      const open = it ? 'Apri la barra laterale' : 'Open the sidebar';
      final toggle = find.byWidgetPredicate((w) => w is PostinoIconButton && w.label == open);
      if (toggle.evaluate().isNotEmpty) await tester.tap(toggle.first);
      await wait(1);
      await tester.tap(aurora.first);
    }
    await shot('01-posta-unificata');

    await tester.tap(find.textContaining(it ? 'Lancio della nuova app' : 'New app launch').first);
    await wait(5);
    await shot('02-conversazione');

    openSearch();
    await wait(2);
    await tester.enterText(find.byType(EditableText).first, it ? 'da:marta' : 'from:martha');
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(2);
    if (tablet) await tester.tap(aurora.last);
    await shot('03-ricerca');

    unawaited(Routefly.navigate(app.routePaths.posta.path));
    await wait(2);
    unawaited(Routefly.push<void>(app.routePaths.impostazioni.scorrimento));
    await shot('04-scorrimento');

    unawaited(Routefly.navigate(app.routePaths.posta.path));
    await wait(2);
    await tester.tap(find.byType(WriteFab));
    await wait(3);
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), 'team@example.com');
    await tester.enterText(fields.at(3), it ? 'Programma del workshop' : 'Workshop agenda');
    tester
        .widget<PostinoRichEditor>(find.byType(PostinoRichEditor))
        .controller
        .replaceText(
          0,
          0,
          it
              ? 'Ciao a tutti,\n\necco il programma delle tre giornate di febbraio: la mattina le sessioni, il '
                    'pomeriggio i laboratori a gruppi.\n\nFatemi sapere entro venerdì chi partecipa.\n\nA presto!'
              : 'Hi all,\n\nhere is the agenda for the three days in February: talks in the morning, group '
                    'workshops in the afternoon.\n\nLet me know by Friday who is joining.\n\nSee you soon!',
          null,
        );
    FocusManager.instance.primaryFocus?.unfocus();
    await shot('05-nuovo-messaggio');
  }, skip: _lang.isEmpty || kIsWeb);
}
