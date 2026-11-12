// Un solo proprietario della sync tra l'isolate dell'app e quello in background (#212): la porta registrata
// con IsolateNameServer.
import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync/sync_owner.dart';

void main() {
  const name = 'postino.sync.test';
  const quick = Duration(milliseconds: 50);
  SyncOwner owner() =>
      SyncOwner(name: name, answerWithin: quick, syncWithin: const Duration(seconds: 5), retryEvery: quick);

  void clear() {
    IsolateNameServer.removePortNameMapping(name);
    IsolateNameServer.removePortNameMapping('$name.worker');
  }

  setUp(clear);
  tearDown(clear);

  test('nobody owns: the first claims, a second does not and asks the owner to sync', () async {
    var asked = 0;
    final app = owner();
    expect(await app.tryClaim(onAsked: () async => asked++), isTrue);

    expect(await owner().tryClaim(), isFalse);
    expect(asked, 1);
  });

  test('released: another claims', () async {
    final app = owner();
    await app.tryClaim();
    app.release();
    expect(await owner().tryClaim(), isTrue);
  });

  test('an owner that does not answer (slow, or gone) keeps its name against a plain claim: false', () async {
    final silent = RawReceivePort((Object? _) {});
    addTearDown(silent.close);
    IsolateNameServer.registerPortWithName(silent.sendPort, name);

    expect(await owner().tryClaim(), isFalse);
    expect(IsolateNameServer.lookupPortByName(name), silent.sendPort);
  });

  test(
    'a silent background task (slow, maybe alive): the app never takes its name, it waits for the release',
    () async {
      final silent = RawReceivePort((Object? _) {});
      addTearDown(silent.close);
      IsolateNameServer.registerPortWithName(silent.sendPort, name);
      IsolateNameServer.registerPortWithName(silent.sendPort, '$name.worker');
      final app = owner();

      expect(await app.tryClaim(takeOver: true), isFalse);
      await Future<void>.delayed(quick * 3);
      expect(await app.tryClaim(takeOver: true), isFalse);
      expect(IsolateNameServer.lookupPortByName(name), silent.sendPort);

      // Its release (the end of the task, or its stop callback).
      clear();
      expect(await app.tryClaim(takeOver: true), isTrue);
    },
  );

  test(
    'the background task marks itself before it takes the name; a task that finds the name taken leaves no mark',
    () async {
      final app = owner();
      expect(await app.tryClaim(takeOver: true), isTrue);
      expect(IsolateNameServer.lookupPortByName('$name.worker'), isNull);

      expect(await owner().tryClaim(), isFalse);
      expect(IsolateNameServer.lookupPortByName('$name.worker'), isNull);
      expect(app.owns, isTrue);
    },
  );

  test(
    'another task\'s mark with the name free (it is taking it, or left the mark): the task skips, no loop',
    () async {
      final other = RawReceivePort();
      addTearDown(other.close);
      IsolateNameServer.registerPortWithName(other.sendPort, '$name.worker');
      expect(await owner().tryClaim(), isFalse);
    },
  );

  test('the background task marks its name; its release clears both', () async {
    final task = owner();
    expect(await task.tryClaim(), isTrue);
    expect(IsolateNameServer.lookupPortByName('$name.worker'), IsolateNameServer.lookupPortByName(name));
    task.release();
    expect(IsolateNameServer.lookupPortByName('$name.worker'), isNull);
    expect(IsolateNameServer.lookupPortByName(name), isNull);
  });

  test('the app takes over a name that does not answer (an engine Android destroyed)', () async {
    final dead = RawReceivePort();
    IsolateNameServer.registerPortWithName(dead.sendPort, name);
    dead.close();

    expect(await owner().tryClaim(takeOver: true), isTrue);
  });

  test('claim waits for the background owner to release, then owns', () async {
    final background = owner();
    await background.tryClaim();
    var claimed = false;
    final app = owner();
    final claim = app.claim().then((_) => claimed = true);
    await Future<void>.delayed(quick * 3);
    expect(claimed, isFalse);

    background.release();
    await claim;
    expect(claimed, isTrue);
    expect(await owner().tryClaim(), isFalse);
  });

  test('a release after the name was taken over leaves the new owner in place', () async {
    final slow = owner();
    await slow.tryClaim();
    IsolateNameServer.removePortNameMapping(name);
    final next = owner();
    expect(await next.tryClaim(takeOver: true), isTrue);

    expect(slow.owns, isFalse);
    expect(next.owns, isTrue);
    slow.release();
    expect(await owner().tryClaim(), isFalse);
  });

  test('the ask waits for the owner to sync: the background task stays alive while the app syncs', () async {
    final syncing = Completer<void>();
    await owner().tryClaim(onAsked: () => syncing.future);
    var answered = false;
    final ask = owner().tryClaim().then((owned) => answered = true);
    await Future<void>.delayed(quick * 3);
    expect(answered, isFalse);

    syncing.complete();
    await ask;
    expect(answered, isTrue);
  });

  test('released while it waits: the claim gives up and never owns', () async {
    final background = owner();
    await background.tryClaim();
    final app = owner();
    final claim = app.claim();
    await Future<void>.delayed(quick);
    app.release();
    background.release();
    await claim;

    expect(app.owns, isFalse);
    expect(await owner().tryClaim(), isTrue);
  });
}
