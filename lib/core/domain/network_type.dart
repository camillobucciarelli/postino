/// Which network the device is on, for large downloads (ADR 0015). Same question as `Connectivity.isOnWifi`
/// in the model manager (#108), so the two can merge.
abstract interface class NetworkType() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Whether the device is on Wi-Fi now; false on cellular and when it cannot tell (desktop): those ask first.
  Future<bool> isOnWifi();
}
