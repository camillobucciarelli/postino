import 'result.dart';

/// The local error log (#116): Dart errors and Failures, kept encrypted on the device for the Segnalazione di un
/// problema. Never holds tokens or passwords; subjects and addresses may stay. The real one in core/data.
abstract interface class ErrorLog() {
  /// Interfaccia: nessuno stato da costruire.
  this;

  /// Appends [error], with its [stack] and the [context] it happened in. Never throws.
  /// [crash]: an uncaught error, which leaves the mark [takeCrashMark] finds at the next start.
  void record(Object error, {StackTrace? stack, String? context, bool crash = false});

  /// The whole log decrypted, oldest entry first; empty when there is none.
  Future<String> read();

  /// Empties the log, crash mark included (Rimozione di un Account).
  Future<void> clear();

  /// True once after a run that ended with an uncaught error: the mark is gone after this.
  Future<bool> takeCrashMark();
}

/// The Failures worth a line in the log.
extension FailureLog on ErrorLog {
  /// Records [failure] seen in [context], unless it is an [OfflineFailure]: no network is not an error, and
  /// offline every poll would add one.
  void failure(String context, Failure failure) {
    if (failure is! OfflineFailure) record(failure, context: context);
  }
}
