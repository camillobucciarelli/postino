import 'package:injectable/injectable.dart';

import '../domain/network_type.dart';

/// Wi-Fi or cellular as set here (#107): no real detection until the model manager (#108).
/// QA and tests flip [onWifi] to simulate a cellular network.
@LazySingleton(as: NetworkType)
class SimulatedNetworkType() implements NetworkType {
  /// Wi-Fi by default; false simulates a cellular network.
  bool onWifi = true;

  @override
  Future<bool> isOnWifi() async => onWifi;
}
