// The system's Indietro (Android, #237): from an Account or a folder it goes to the Posta unificata, whose Indietro
// leaves the app; an open Conversazione closes first; Impostazioni pops first.
import 'dart:async';

import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/message.dart' show draftLabelId, sentLabelId, trashLabelId;
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/i18n/strings.g.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/fake_mail_provider.dart';
import '../../support/harness.dart';

const _phone = Size(390, 844);
const _desktop = Size(1600, 900);

/// How many times the app asked the system to leave (an Indietro it did not handle).
var _exits = 0;

Future<void> _start(WidgetTester tester, Size size) async {
  _exits = 0;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'SystemNavigator.pop') _exits++;
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create();
  (await h.addAccount('a1')).deliver(msg('m1', subject: 'Primo'));
  LocaleSettings.setLocaleSync(AppLocale.it);
  await tester.pumpWidget(TranslationProvider(child: const PostinoApp()));
  // Routefly keeps the last navigation in statics.
  unawaited(Routefly.navigate(routePaths.posta.path));
  await tester.pumpAndSettle();
}

Future<void> _go(WidgetTester tester, String path) async {
  unawaited(Routefly.navigate(path));
  await tester.pumpAndSettle();
}

/// The Posta unificata is in front (on the wide layout «Posta unificata» is also in the docked drawer).
void _expectUnified() {
  expect(Routefly.currentUri.path, routePaths.posta.path);
  expect(find.byType(ConversationView), findsNothing);
  expect(find.text('Posta unificata'), findsWidgets);
}

/// A system Indietro.
Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

String _inbox() => routePaths.posta.$accountId.path.changes({'accountId': 'a1'});

String _folder(String labelId) =>
    routePaths.posta.$accountId.etichetta.$labelId.changes({'accountId': 'a1', 'labelId': labelId});

void main() {
  for (final (name, size) in [('phone', _phone), ('desktop', _desktop)]) {
    group(name, () {
      for (final (label, path) in [
        ('inbox of an Account', _inbox()),
        ('Cestino', _folder(trashLabelId)),
        ('Bozze', _folder(draftLabelId)),
        ('Inviati', _folder(sentLabelId)),
      ]) {
        testWidgets('Indietro from the $label goes to the Posta unificata, the next one leaves the app', (
          tester,
        ) async {
          await _start(tester, size);
          await _go(tester, path);
          expect(Routefly.currentUri.path, path);

          await _back(tester);
          _expectUnified();
          expect(_exits, 0, reason: 'the first Indietro stays in the app');

          await _back(tester);
          expect(_exits, 1, reason: 'the second Indietro is left to the system, which leaves the app');
        });
      }

      testWidgets('an open Conversazione closes first, then the list goes to the Posta unificata', (tester) async {
        await _start(tester, size);
        await _go(tester, _inbox());
        await tester.tap(find.byKey(const ValueKey('row-a1-m1')));
        await tester.pumpAndSettle();
        expect(find.byType(ConversationView), findsOneWidget);

        await _back(tester);
        expect(find.byType(ConversationView), findsNothing);
        expect(Routefly.currentUri.path, _inbox());

        await _back(tester);
        _expectUnified();
      });
    });
  }

  testWidgets('Impostazioni pops first, back on the list it was opened from', (tester) async {
    await _start(tester, _phone);
    await _go(tester, _inbox());
    unawaited(Routefly.push<void>(routePaths.impostazioni.path));
    await tester.pumpAndSettle();

    await _back(tester);
    expect(Routefly.currentUri.path, _inbox());
    await _back(tester);
    _expectUnified();
  });
}
