import 'dart:async';

import 'package:postino/core/domain/error_log.dart';
import 'package:postino/core/domain/launch_at_login.dart';
import 'package:postino/core/domain/platform_services.dart';

class FakeSecureStore() implements SecureStore {
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

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Time moves only with [advance], which also fires the [every] tickers that came due.
class FakeClock(var DateTime current) implements Clock {
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

class FakeConnectivity() implements Connectivity {
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

  /// Whether the network is Wi-Fi, for the model downloads.
  bool wifi = true;

  @override
  Future<bool> isOnWifi() async => wifi;
}

/// Records every link Postino asked to open, instead of opening it.
class FakeLinkOpener() implements LinkOpener {
  final opened = <Uri>[];
  @override
  Future<void> open(Uri url) async => opened.add(url);
}

/// Records every Save As instead of showing the dialog.
class FakeFileSaver() implements FileSaver {
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
class FakeBackgroundSender() implements BackgroundSender {
  final holds = <String>[];
  final releases = <String>[];
  @override
  Future<void> hold(String accountId) async => holds.add(accountId);
  @override
  Future<void> release(String accountId) async => releases.add(accountId);
}

/// The OS's login items, in memory: [supported] false like a phone, until a test makes it a desktop.
class FakeLaunchAtLogin() implements LaunchAtLogin {
  @override
  bool supported = false;

  /// Whether the OS would start Postino at login.
  bool enabled = false;

  /// While set, a change throws it: the OS refused.
  Exception? failure;

  /// Every change asked, in order.
  final changes = <bool>[];

  /// While set, reading the state throws it.
  Exception? readFailure;

  @override
  Future<bool> isEnabled() async {
    if (readFailure case final f?) throw f;
    return enabled;
  }

  @override
  Future<void> setEnabled({required bool enabled}) async {
    changes.add(enabled);
    if (failure case final f?) throw f;
    this.enabled = enabled;
  }
}

/// Keeps what it is given in memory: (error, crash).
class FakeErrorLog() implements ErrorLog {
  final entries = <(Object, bool)>[];

  @override
  void record(Object error, {StackTrace? stack, String? context, bool crash = false}) => entries.add((error, crash));

  @override
  Future<String> read() async => [for (final (e, _) in entries) '$e'].join('\n');

  @override
  Future<void> clear() async => entries.clear();

  @override
  Future<bool> takeCrashMark() async => false;
}
