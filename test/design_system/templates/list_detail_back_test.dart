// PostinoListDetailLayout (#365): built with a detail open before Android resumes the app (a cold start from a
// notification), it still declares it handles the system's Indietro once resumed, so the first one closes the detail.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';

import '../../support/system_back.dart';

void main() {
  testWidgets('a detail open before the app resumes: the first Indietro closes it', (tester) async {
    final system = SystemBack.install(tester, resumed: false);
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: PostinoTheme.light(),
        home: Scaffold(
          body: PostinoListDetailLayout(
            list: const Text('lista'),
            detail: const Text('dettaglio'),
            detailKey: 1,
            empty: const SizedBox(),
            onClose: () => closed++,
            resizeLabel: 'Larghezza lista',
            resizeValueLabel: (w) => '$w',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    await system.press(tester);
    expect(closed, 1);
    expect(system.exits, 0);
  });
}
