import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/features/posta/presentation/conversation_view.dart';
import 'package:postino/main.dart';
import 'package:routefly/routefly.dart';

import '../../support/ui.dart';

/// The Account the notification tests deliver to.
const notifiedAccount = 'a1';

/// The Posta unificata is in front, with no Conversazione open.
void expectUnified() {
  expect(Routefly.currentUri.path, routePaths.posta.path);
  expect(find.byType(ConversationView), findsNothing);
  expect(find.text('Posta unificata'), findsOneWidget);
}

/// The Conversazione's own Indietro.
Future<void> tapBack(WidgetTester tester) async {
  await tester.tap(icon(PostinoIcons.arrowLeft));
  await tester.pumpAndSettle();
}
