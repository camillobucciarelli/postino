// The periodic task of the background sync (#212): there while an Account is, once whatever the app starts.
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/mail_store.dart';
import 'package:postino/core/data/sync/periodic_schedule.dart';
import 'package:postino/main.dart';

import '../../../support/harness.dart';

void main() {
  late Harness h;

  setUp(() async => h = await Harness.create());

  test('no Account: not scheduled; the first one schedules it, once even after more app starts', () async {
    final schedule = getIt<PeriodicSchedule>()..start();
    await pumpEventQueue();
    expect(h.periodic.scheduled, isFalse);

    await h.addAccount('a');
    await h.addAccount('b');
    await pumpEventQueue();
    expect(h.periodic.scheduled, isTrue);

    for (var i = 0; i < 2; i++) {
      await schedule.stop();
      schedule.start();
      await pumpEventQueue();
    }
    expect(h.periodic.registrations, 1);
    // One call per start, not per Account: the second Account added nothing.
    expect(h.periodic.calls, 3);
  });

  test('the last Account removed: cancelled', () async {
    await h.addAccount('a');
    await h.addAccount('b');
    getIt<PeriodicSchedule>().start();
    await pumpEventQueue();

    await getIt<MailStore>().removeAccount('a', at: h.clock.now());
    await pumpEventQueue();
    expect(h.periodic.scheduled, isTrue);

    await getIt<MailStore>().removeAccount('b', at: h.clock.now());
    await pumpEventQueue();
    expect(h.periodic.scheduled, isFalse);
  });
}
