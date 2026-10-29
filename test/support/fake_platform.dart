import 'dart:async';

import 'package:postino/core/domain/platform_services.dart';

class FakeSecureStore implements SecureStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Time moves only with [advance], which also fires the [every] tickers that came due.
class FakeClock implements Clock {
  FakeClock(this.current);
  DateTime current;
  final _tickers = <(Duration, StreamController<void>, List<Duration>)>[];

  @override
  DateTime now() => current;

  @override
  Stream<void> every(Duration period) {
    late final StreamController<void> c;
    final elapsed = [Duration.zero];
    c = StreamController<void>(
      onCancel: () => _tickers.removeWhere((t) => t.$2 == c),
    );
    _tickers.add((period, c, elapsed));
    return c.stream;
  }

  void advance(Duration d) {
    current = current.add(d);
    for (final (period, c, elapsed) in [..._tickers]) {
      elapsed[0] += d;
      while (elapsed[0] >= period) {
        elapsed[0] -= period;
        c.add(null);
      }
    }
  }
}

class FakeConnectivity implements Connectivity {
  final _changes = StreamController<bool>.broadcast();
  bool _online = true;

  @override
  bool get isOnline => _online;

  set online(bool value) {
    _online = value;
    _changes.add(value);
  }

  @override
  Stream<bool> get onChanged => _changes.stream;
}
