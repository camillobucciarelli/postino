import 'package:postino/core/domain/platform_services.dart';

class FakeSecureStore implements SecureStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class FakeClock implements Clock {
  FakeClock(this.current);
  DateTime current;
  @override
  DateTime now() => current;
}

class FakeConnectivity implements Connectivity {
  @override
  bool isOnline = true;
  @override
  Stream<bool> get onChanged => const Stream.empty();
}
