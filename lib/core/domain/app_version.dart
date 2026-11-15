/// The version of Postino that is running (#297), as the release set it with `--dart-define`.
class const AppVersion({
  /// X.Y.Z of the release; empty in a development build.
  final String version = '',

  /// The build number of the release (build_number.sh); 0 in a development build.
  final int build = 0,
}) {
  /// Crea la versione.
  this;

  /// What this build was compiled with: POSTINO_VERSION (X.Y.Z of version.sh) and POSTINO_BUILD (build_number.sh).
  const AppVersion.installed()
    : this(version: const String.fromEnvironment('POSTINO_VERSION'), build: const int.fromEnvironment('POSTINO_BUILD'));

  /// A development build has no version to show: the release sets it.
  bool get isDevelopment => version.isEmpty;
}
