// Impostazioni › Account › Etichette automatiche (#107): the switch and the description of each Etichetta, the state
// of the model download in the page and in the banner above the lists, and «Crea Etichetta».

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/simulated_model_download.dart';
import 'package:postino/core/data/simulated_network_type.dart';
import 'package:postino/core/domain/auto_labels_repository.dart';
import 'package:postino/core/domain/model_download.dart';
import 'package:postino/core/domain/model_download_state.dart';
import 'package:postino/core/domain/network_type.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/fake_model_download.dart';
import '../../support/harness.dart';

const _cost = 310 * 1000 * 1000;

/// The app at desktop width, Italian; the Account a1 has the Etichetta Viaggi.
Future<({Harness h, FakeMailProvider provider})> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1200, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  final provider = await h.addAccount('a1');
  provider.deliver(msg('x', subject: 'Una email'));
  LocaleSettings.setLocaleSync(AppLocale.it);
  return (h: h, provider: provider);
}

Future<void> _run(WidgetTester tester) async {
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

Future<void> _openPage(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('drawer-impostazioni')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('settings-auto-labels-a1')));
  await tester.pumpAndSettle();
}

SimulatedModelDownload _simulated({required bool wifi}) {
  (getIt<NetworkType>() as SimulatedNetworkType).onWifi = wifi;
  return getIt<ModelDownload>() as SimulatedModelDownload..stepDelay = Duration.zero;
}

Future<FakeModelDownload> _fake() async {
  await getIt.unregister<ModelDownload>();
  final fake = FakeModelDownload();
  getIt.registerSingleton<ModelDownload>(fake);
  return fake;
}

/// Moves the model to [state] and lets the screen follow (the stream delivers in a microtask).
Future<void> emit(WidgetTester tester, FakeModelDownload model, ModelDownloadState state) async {
  model.emit(state);
  await tester.pump();
  await tester.pump();
}

final _row = find.ancestor(of: find.text('Viaggi'), matching: find.byType(PostinoSwitchRow));
final _banner = find.byKey(const ValueKey('model-banner'));
final _page = find.byType(PostinoSettingsPage);

bool _on(WidgetTester tester) => tester.widget<Switch>(find.descendant(of: _row, matching: find.byType(Switch))).value;

Finder _inPage(String text) => find.descendant(of: _page, matching: find.text(text));

void main() {
  testWidgets('the Impostazioni of the drawer lead to the page of the Account', (tester) async {
    await _start(tester);
    await _run(tester);
    await _openPage(tester);
    expect(find.text('Etichette automatiche'), findsWidgets);
    expect(find.text('Impostazioni · a1@example.com'), findsOneWidget);
    expect(find.textContaining('gira sul tuo dispositivo'), findsOneWidget);
    expect(find.text('Viaggi'), findsOneWidget);
    expect(find.text('Crea Etichetta'), findsOneWidget);
    // The intro is for reading and copying: selectable.
    expect(
      find.ancestor(of: find.textContaining('gira sul tuo dispositivo'), matching: find.byType(SelectionArea)),
      findsWidgets,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-auto-labels-a1')), findsOneWidget);
  });

  testWidgets('the switch is one control named by the Etichetta; on shows the description, which saves on blur', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _start(tester);
    final model = _simulated(wifi: true);
    await _run(tester);
    await _openPage(tester);
    expect(find.text('Descrizione (facoltativa)'), findsNothing);
    expect(
      tester.getSemantics(_row),
      matchesSemantics(
        label: 'Viaggi\nAutomatica',
        hasToggledState: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(_on(tester), isTrue);
    expect(model.state, isA<ModelDownloadReady>());
    expect(find.text('Descrizione (facoltativa)'), findsOneWidget);
    expect(find.text('Descrivi che email ci vanno, es. fatture e ricevute dei fornitori'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  fatture dei fornitori ');
    expect(find.text('Descrizione salvata'), findsNothing);
    // Losing the focus saves it and says so, in a live region.
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    final saved = find.text('Descrizione salvata');
    expect(saved, findsOneWidget);
    expect(tester.getSemantics(saved), matchesSemantics(label: 'Descrizione salvata', isLiveRegion: true));
    final stored = (await tester.runAsync(() => getIt<AutoLabelsRepository>().watch('a1').first))!;
    expect(stored.values.single, (automatic: true, description: 'fatture dei fornitori'));

    // Typing again takes the notice away; an unchanged text saves nothing new.
    await tester.enterText(find.byType(TextField), 'fatture dei fornitori ');
    await tester.pump();
    expect(find.text('Descrizione salvata'), findsNothing);
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Descrizione salvata'), findsNothing);

    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(_on(tester), isFalse);
    expect(find.text('Descrizione (facoltativa)'), findsNothing);
    semantics.dispose();
  });

  testWidgets('what was saved is read back when the page opens again', (tester) async {
    await _start(tester);
    _simulated(wifi: true);
    final repo = getIt<AutoLabelsRepository>();
    await tester.runAsync(() async {
      await repo.setAutomatic('a1', 'Label_12', automatic: true);
      await repo.setDescription('a1', 'Label_12', 'biglietti');
    });
    await _run(tester);
    await _openPage(tester);
    expect(_on(tester), isTrue);
    expect(find.text('biglietti'), findsOneWidget);
  });

  testWidgets('on Wi-Fi the first activation downloads at once and the switch stays on', (tester) async {
    await _start(tester);
    final model = _simulated(wifi: true)..failNext = false;
    await _run(tester);
    await _openPage(tester);
    await tester.tap(_row);
    await tester.pump();
    await tester.pump();
    expect(model.state, isNot(isA<ModelDownloadAbsent>()));
    expect(find.textContaining('rete cellulare'), findsNothing);
    expect(_on(tester), isTrue);
    await tester.pumpAndSettle();
    expect(_inPage('Modello pronto'), findsOneWidget);
    expect(_on(tester), isTrue);
  });

  testWidgets('on cellular a dialog asks: the focus is on «Scarica ora» and Esc waits for Wi-Fi', (tester) async {
    await _start(tester);
    final model = _simulated(wifi: false);
    await _run(tester);
    await _openPage(tester);
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(find.text('Scaricare 310 MB su rete cellulare?'), findsOneWidget);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(focused.findAncestorWidgetOfExactType<PostinoButton>()?.label, 'Scarica ora');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Scaricare 310 MB su rete cellulare?'), findsNothing);
    expect(model.state, isA<ModelDownloadWaitingForWifi>());
    expect(_on(tester), isTrue);
    expect(_inPage('In attesa del Wi-Fi'), findsOneWidget);

    // «Scarica ora» opens the question again; Invio takes the default.
    await tester.tap(find.descendant(of: _banner, matching: find.text('Scarica ora')));
    await tester.pumpAndSettle();
    expect(find.text('Scaricare 310 MB su rete cellulare?'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(model.state, isA<ModelDownloadReady>());
  });

  testWidgets('«Aspetta il Wi-Fi» on the dialog waits too', (tester) async {
    await _start(tester);
    final model = _simulated(wifi: false);
    await _run(tester);
    await _openPage(tester);
    await tester.tap(_row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aspetta il Wi-Fi'));
    await tester.pumpAndSettle();
    expect(model.state, isA<ModelDownloadWaitingForWifi>());
  });

  testWidgets('a failed download shows the reason and «Riprova» downloads again', (tester) async {
    await _start(tester);
    final model = _simulated(wifi: true)..failNext = true;
    await _run(tester);
    await _openPage(tester);
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(model.state, isA<ModelDownloadFailed>());
    expect(_inPage('Download del modello non riuscito'), findsOneWidget);
    expect(_inPage('Connessione interrotta.'), findsOneWidget);
    await tester.tap(find.descendant(of: _page, matching: find.text('Riprova')));
    await tester.pumpAndSettle();
    expect(model.state, isA<ModelDownloadReady>());
  });

  testWidgets('each state in the page and in the banner above the list', (tester) async {
    final semantics = tester.ensureSemantics();
    await _start(tester);
    final model = await _fake();
    await _run(tester);
    expect(_banner, findsNothing);

    // Preparing: a spinner.
    await emit(tester, model, const ModelDownloadPreparing());
    expect(find.descendant(of: _banner, matching: find.byType(PostinoSpinner)), findsOneWidget);
    expect(find.text('Preparazione del modello'), findsWidgets);
    expect(banner(tester).tone, PostinoBannerTone.info);

    // Waiting for Wi-Fi: the action «Scarica ora».
    await emit(tester, model, const ModelDownloadWaitingForWifi(_cost));
    expect(find.text('In attesa del Wi-Fi'), findsOneWidget);
    expect(find.text('Scarica ora'), findsOneWidget);
    await tester.tap(find.text('Scarica ora'));
    await tester.pumpAndSettle();
    expect(find.text('Scaricare 310 MB su rete cellulare?'), findsOneWidget);
    await tester.tap(find.text('Scarica ora').last);
    await tester.pumpAndSettle();
    expect(model.downloads, 1);

    // Downloading: the bar and «167 MB di 310 MB · 54%».
    await emit(tester, model, const ModelDownloadInProgress(167400000, _cost));
    expect(find.descendant(of: _banner, matching: find.byType(PostinoProgressBar)), findsOneWidget);
    expect(find.text('167 MB di 310 MB · 54%'), findsOneWidget);
    expect(banner(tester).tone, PostinoBannerTone.info);
    // The screen reader hears the bar in steps of 25%, not the figure that changes at every tick.
    final bar = tester.getSemantics(find.byType(PostinoProgressBar));
    expect(bar.label, contains('Download del modello'));
    expect(bar.value, '50%');
    expect(find.bySemanticsLabel(RegExp('167 MB')), findsNothing);

    // Failed: danger, the reason and «Riprova».
    await emit(tester, model, const ModelDownloadFailed(OfflineFailure()));
    expect(banner(tester).tone, PostinoBannerTone.danger);
    expect(find.text('Connessione interrotta.'), findsOneWidget);
    await tester.tap(find.text('Riprova'));
    expect(model.downloads, 2);

    // Ready: the banner goes away, a snackbar says so (once, with the list and the Conversazione side by side).
    await tester.tap(find.text('Una email'));
    await tester.pumpAndSettle();
    await emit(tester, model, const ModelDownloadReady());
    await tester.pump(const Duration(milliseconds: 500));
    expect(_banner, findsNothing);
    expect(find.text('Etichette automatiche pronte'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('the page shows the state of the model, and «Modello pronto» stays there', (tester) async {
    await _start(tester);
    final model = await _fake();
    await _run(tester);
    await _openPage(tester);
    expect(_inPage('Modello pronto'), findsNothing);
    await emit(tester, model, const ModelDownloadInProgress(0, _cost));
    expect(_inPage('0 MB di 310 MB · 0%'), findsOneWidget);
    await emit(tester, model, const ModelDownloadReady());
    expect(_inPage('Modello pronto'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('«Crea Etichetta» refuses a bad name in place and creates a good one', (tester) async {
    final (:h, :provider) = await _start(tester);
    _simulated(wifi: true);
    await _run(tester);
    await _openPage(tester);
    await tester.tap(find.text('Crea Etichetta'));
    await tester.pumpAndSettle();
    final create = find.text('Crea').last;

    Future<void> tryName(String name, String error) async {
      await tester.enterText(find.byType(TextField), name);
      await tester.tap(create);
      await tester.pump();
      expect(find.text(error), findsOneWidget);
      expect(find.text('Nome dell\'Etichetta'), findsOneWidget, reason: 'the dialog stays open');
    }

    await tryName('  ', 'Scrivi un nome per l\'Etichetta.');
    await tryName('viaggi', 'Esiste già un\'Etichetta con questo nome.');
    await tryName('Progetti/', 'Ogni livello ha bisogno di un nome: niente «/» all\'inizio, alla fine o doppie.');
    expect(provider.labels.map((l) => l.name), isNot(contains('Progetti/')));

    await tester.enterText(find.byType(TextField), 'Progetti/Postino');
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('Nome dell\'Etichetta'), findsNothing);
    expect(provider.labels.map((l) => l.name), contains('Progetti/Postino'));
    expect(find.text('Progetti/Postino'), findsOneWidget);
    expect(h, isNotNull);
  });
}

PostinoBanner banner(WidgetTester tester) => tester.widget<PostinoBanner>(_banner);
