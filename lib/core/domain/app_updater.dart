import 'result.dart';

/// A version of Postino newer than the one installed (#287): its number for the Banner, and where to get it.
typedef AppUpdate = ({String version, Uri url});

/// What «Cerca aggiornamenti» found; a site that could not be read (no network, a bad answer) is an [Err].
enum UpdateCheck() {
  /// The updater answered in its own window (Sparkle on macOS).
  shown,

  /// Nothing newer.
  upToDate,

  /// A newer version: [AppUpdater.available] names it.
  available,
}

/// Aggiornamenti di Postino: Sparkle on macOS (#122), with its own window; on Android and iOS (#287) the release's
/// version file, read at most once a day, and a Banner while a newer version is not dismissed. The real ones in
/// core/data, a fake in tests.
abstract interface class AppUpdater() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// False where Postino does not look for updates (Windows, Linux, a development build).
  bool get supported;

  /// The newer version found and not dismissed; null otherwise, and always where the updater has its own window.
  AppUpdate? get available;

  /// [available], each time it changes.
  Stream<AppUpdate?> get changes;

  /// At start and back in foreground: looks for a new version unless it did in the last day. Never fails.
  Future<void> checkDaily();

  /// Looks for a new version now; a version found shows again even if dismissed.
  Future<Result<UpdateCheck>> checkForUpdates();

  /// The user closed the Banner: [available] stays null until a newer version.
  Future<void> dismiss();

  /// Opens where [available] is downloaded (the browser, the App Store).
  Future<void> download();
}
