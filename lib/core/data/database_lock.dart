import 'package:sqlite3/sqlite3.dart';

/// Runs [body] holding the exclusive lock of the SQLite file at [path], between isolates and between processes (#263):
/// the app and a background engine (WorkManager, BGTaskScheduler, a notification button) may start together.
///
/// Not `RandomAccessFile.lock`: its POSIX locks belong to the process, so two isolates of the app both get them.
/// SQLite tracks its locks inside the process too, and the system drops them when the process dies. The lock is
/// waited for without blocking the isolate, at most [timeout]: past it the SQLite busy error propagates and the
/// start fails, to be tried again, rather than running unguarded.
Future<T> withDatabaseLock<T>(
  String path,
  Future<T> Function() body, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final lock = sqlite3.open(path);
  try {
    final waited = Stopwatch()..start();
    while (true) {
      try {
        lock.execute('BEGIN EXCLUSIVE');
        break;
      } on SqliteException catch (e) {
        if (e.resultCode != SqlError.SQLITE_BUSY || waited.elapsed > timeout) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
    return await body();
  } finally {
    // Closing ends the empty transaction, and with it the lock.
    lock.close();
  }
}
