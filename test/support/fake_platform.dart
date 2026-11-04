import 'dart:async';

import 'package:postino/core/domain/platform_services.dart';

class FakeSecureStore implements SecureStore {
  final values = <String, String>{};

  /// While set, every read throws it: a locked keychain, access denied.
  Exception? failure;
  @override
  Future<String?> read(String key) async {
    if (failure case final f?) throw f;
    return values[key];
  }

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
    // ignore: close_sinks, the listener's cancel removes the ticker.
    late final StreamController<void> c;
    final elapsed = [Duration.zero];
    c = StreamController<void>(onCancel: () => _tickers.removeWhere((t) => t.$2 == c));
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

/// Records every link Postino asked to open, instead of opening it.
class FakeLinkOpener implements LinkOpener {
  final opened = <Uri>[];
  @override
  Future<void> open(Uri url) async => opened.add(url);
}

/// Records every Save As instead of showing the dialog.
class FakeFileSaver implements FileSaver {
  final saved = <(String path, String name)>[];
  @override
  bool available = true;

  /// While set, a save throws it: a full disk, a folder it may not write to.
  Exception? failure;

  /// While set, the dialog stays open until it completes; true saves, false is the user's Annulla.
  Completer<bool>? dialog;
  @override
  Future<void> save(String path, String name) async {
    if (failure case final f?) throw f;
    if (dialog case final d?) {
      if (!await d.future) return;
    }
    saved.add((path, name));
  }
}

/// Records every hold and release instead of asking the platform.
class FakeBackgroundSender implements BackgroundSender {
  final holds = <String>[];
  final releases = <String>[];
  @override
  Future<void> hold(String accountId) async => holds.add(accountId);
  @override
  Future<void> release(String accountId) async => releases.add(accountId);
}
