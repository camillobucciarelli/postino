import 'package:get_it/get_it.dart';

import '../../domain/settings_backend.dart';
import '../gmail/drive_http.dart';
import '../gmail/drive_settings_backend.dart';

/// Where the Account [accountId] keeps the Impostazioni di Postino, created on first use; tests register fakes
/// by Account id beforehand. The one place that picks the concrete backend (ADR 0016).
SettingsBackend settingsBackendFor(String accountId) {
  final g = GetIt.I;
  if (!g.isRegistered<SettingsBackend>(instanceName: accountId)) {
    // ponytail: Drive is the only backend; the export/import file and other Providers branch here.
    g.registerLazySingleton<SettingsBackend>(
      () => DriveSettingsBackend(DriveHttp(accountId, g(), g(), g())),
      instanceName: accountId,
    );
  }
  return g<SettingsBackend>(instanceName: accountId);
}
