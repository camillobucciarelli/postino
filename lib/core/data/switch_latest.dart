import 'dart:async';

/// The stream of [inner] for the latest value of [outer]: each new value drops the previous inner stream (rxdart's
/// `switchMap`, without the dependency). Ends once [outer] and the last inner stream have both ended.
Stream<T> switchLatest<S, T>(Stream<S> outer, Stream<T> Function(S value) inner) {
  late final StreamController<T> out;
  StreamSubscription<S>? source;
  StreamSubscription<T>? current;
  var outerDone = false;
  var innerDone = true;
  void closeIfDone() {
    if (outerDone && innerDone) unawaited(out.close());
  }

  out = StreamController<T>(
    onListen: () => source = outer.listen(
      (value) {
        unawaited(current?.cancel());
        innerDone = false;
        current = inner(value).listen(
          out.add,
          onError: out.addError,
          onDone: () {
            innerDone = true;
            closeIfDone();
          },
        );
      },
      onError: out.addError,
      onDone: () {
        outerDone = true;
        closeIfDone();
      },
    ),
    onPause: () {
      source?.pause();
      current?.pause();
    },
    onResume: () {
      source?.resume();
      current?.resume();
    },
    onCancel: () async {
      await current?.cancel();
      await source?.cancel();
    },
  );
  return out.stream;
}
