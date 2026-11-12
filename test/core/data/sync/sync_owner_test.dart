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

  setUp(() => IsolateNameServer.removePortNameMapping(name));
  tearDown(() => IsolateNameServer.removePortNameMapping(name));

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

  test('a stale owner (its isolate gone, the name left behind) does not block: the name is taken over', () async {
    final dead = RawReceivePort();
    IsolateNameServer.registerPortWithName(dead.sendPort, name);
    dead.close();

    expect(await owner().tryClaim(), isTrue);
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
    expect(await next.tryClaim(), isTrue);

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
