import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/switch_latest.dart';

void main() {
  test('each outer value replaces the inner stream; the old one is cancelled', () async {
    final outer = StreamController<int>();
    final inners = {1: StreamController<String>(), 2: StreamController<String>()};
    addTearDown(() => Future.wait([outer.close(), for (final c in inners.values) c.close()]));
    final got = <String>[];
    final sub = switchLatest(outer.stream, (int i) => inners[i]!.stream).listen(got.add);
    outer.add(1);
    await pumpEventQueue();
    inners[1]!.add('a');
    outer.add(2);
    await pumpEventQueue();
    expect(inners[1]!.hasListener, isFalse);
    inners[2]!.add('b');
    await pumpEventQueue();
    expect(got, ['a', 'b']);
    await sub.cancel();
    expect(inners[2]!.hasListener, isFalse);
    expect(outer.hasListener, isFalse);
  });

  test('errors of either stream come through', () async {
    final outer = StreamController<int>();
    final inner = StreamController<String>();
    addTearDown(() => Future.wait([outer.close(), inner.close()]));
    final errors = <Object>[];
    final sub = switchLatest(outer.stream, (_) => inner.stream).listen(null, onError: errors.add);
    outer.add(1);
    await pumpEventQueue();
    inner.addError('inner');
    outer.addError('outer');
    await pumpEventQueue();
    expect(errors, ['inner', 'outer']);
    await sub.cancel();
  });

  test('done only once the outer and the last inner stream are both done', () async {
    final outer = StreamController<int>();
    final inner = StreamController<String>();
    var done = false;
    switchLatest(outer.stream, (_) => inner.stream).listen(null, onDone: () => done = true);
    outer.add(1);
    await pumpEventQueue();
    await outer.close();
    await pumpEventQueue();
    expect(done, isFalse);
    await inner.close();
    await pumpEventQueue();
    expect(done, isTrue);
  });

  test('a pause holds both streams', () async {
    final outer = StreamController<int>();
    final inner = StreamController<String>();
    addTearDown(() => Future.wait([outer.close(), inner.close()]));
    final sub = switchLatest(outer.stream, (_) => inner.stream).listen(null);
    outer.add(1);
    await pumpEventQueue();
    sub.pause();
    expect(outer.isPaused, isTrue);
    expect(inner.isPaused, isTrue);
    sub.resume();
    expect(inner.isPaused, isFalse);
    await sub.cancel();
  });
}
