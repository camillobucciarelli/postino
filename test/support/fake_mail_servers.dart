import 'package:postino/core/domain/connection_tester.dart';
import 'package:postino/core/domain/mail_servers.dart';
import 'package:postino/core/domain/result.dart';
import 'package:postino/core/domain/server_discovery.dart';

/// Autodiscovery without the network: [servers] by address, null for the others.
class FakeServerDiscovery() implements ServerDiscovery {
  final servers = <String, ServerSettings>{};
  final asked = <String>[];

  @override
  Future<ServerSettings?> discover(String address) async {
    asked.add(address);
    return servers[address];
  }
}

/// The test connection without sockets: accepts [password] only, unless [failure] is set; records each test.
class FakeConnectionTester() implements ConnectionTester {
  String password = 'app-password-1';
  Failure? failure;
  final tested = <(ServerSettings servers, String user)>[];

  @override
  Future<Result<void>> test(ServerSettings servers, {required String user, required String password}) async {
    tested.add((servers, user));
    if (failure case final f?) return Err(f);
    return password == this.password ? const Ok(null) : const Err(AuthFailure());
  }
}
