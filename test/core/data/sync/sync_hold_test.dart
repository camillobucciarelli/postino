// The app's hold on the sync (#212): claimed at start, claimed back when lost, given up at stop.
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/sync/account_queue.dart';
import 'package:postino/core/data/sync/sync_hold.dart';
import 'package:postino/core/data/sync/sync_owner.dart';

void main() {
  const name = 'postino.sync.hold-test';
  const quick = Duration(milliseconds: 50);
  late SyncOwner owner;
  late AccountQueue queue;
  late SyncHold hold;
  var owned = 0;

  setUp(() {
    IsolateNameServer.removePortNameMapping(name);
    owned = 0;
    owner = SyncOwner(name: name, answerWithin: quick, retryEvery: quick);
    queue = AccountQueue();
    hold = SyncHold(owner, queue, onAsked: () async {}, onOwned: () => owned++);
  });
  tearDown(() => IsolateNameServer.removePortNameMapping(name));

  test('start: owned, the refresh before the queue runs anything', () async {
    final order = <String>[];
    hold = SyncHold(owner, queue, onAsked: () async {}, onOwned: () => order.add('owned'))..start();
    await queue.run('a', () async => order.add('work'));
    expect(order, ['owned', 'work']);
    expect(owner.owns, isTrue);
  });

  test('the name lost: ensure claims it back, once; stop gives it up', () async {
    hold.start();
    await hold.owned;
    IsolateNameServer.removePortNameMapping(name);
    hold
      ..ensure()
      ..ensure();
    await hold.owned;
    expect(owner.owns, isTrue);
    expect(owned, 2);

    hold.stop();
    expect(IsolateNameServer.lookupPortByName(name), isNull);
    hold.ensure();
    expect(IsolateNameServer.lookupPortByName(name), isNull);
  });
}
