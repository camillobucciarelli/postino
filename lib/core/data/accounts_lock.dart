import 'package:injectable/injectable.dart';

/// One at a time: connecting an Account (its credentials and its row) and removing one (ADR 0016), so a removal
/// never deletes the credentials a reconnection has just written.
// ponytail: one global lock, not one per Account; the two hold it only for a few writes.
@lazySingleton
class AccountsLock() {
  Future<void> _tail = Future<void>.value();

  /// Runs [op] after the ones before it; an error stays with its caller and does not block the next.
  Future<T> run<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }
}
