// The on-device model manager (#108), with the network and the file system in memory.
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postino/core/data/file_model_manager.dart';
import 'package:postino/core/domain/model_descriptor.dart';
import 'package:postino/core/domain/model_state.dart';
import 'package:postino/core/domain/result.dart';

import '../../support/fake_platform.dart';

void main() {
  final bytes = utf8.encode('weights of a very small model');
  final model = ModelDescriptor(
    id: 'embedding',
    url: Uri.parse('https://models.example/m.litertlm'),
    sizeBytes: bytes.length,
    sha256: sha256.convert(bytes).toString(),
    fileName: 'm.litertlm',
  );

  late MemoryFileSystem fs;
  late FakeConnectivity network;

  late List<http.BaseRequest> requests;

  /// What the server answers: by default the model in two chunks.
  late Future<http.StreamedResponse> Function(http.BaseRequest) serve;
  late FileModelManager manager;
  late List<ModelState> states;

  setUp(() {
    fs = MemoryFileSystem();
    network = FakeConnectivity();
    requests = [];
    serve = (_) async => http.StreamedResponse(Stream.fromIterable([bytes.sublist(0, 10), bytes.sublist(10)]), 200);
    manager = FileModelManager(
      MockClient.streaming((r, _) {
        requests.add(r);
        return serve(r);
      }),
      network,
      fs.directory('/support/models'),
    );
    states = [];
    manager.watch(model).listen(states.add);
  });

  test('on Wi-Fi the first activation downloads at once', () async {
    await manager.activate(model);
    expect(requests.single.url, model.url);
    await pumpEventQueue();
    expect(states.last, isA<ModelReady>().having((s) => s.path, 'path', '/support/models/m.litertlm'));
    expect(fs.file('/support/models/m.litertlm').readAsBytesSync(), bytes);
    expect(fs.file('/support/models/m.litertlm.part').existsSync(), isFalse);
  });

  test('off Wi-Fi it waits for the confirmation, showing the size', () async {
    network.wifi = false;
    await manager.activate(model);
    expect(requests, isEmpty);
    await pumpEventQueue();
    expect(states.last, isA<ModelAwaitingConfirmation>().having((s) => s.sizeBytes, 'sizeBytes', bytes.length));

    await manager.download(model);
    expect(requests, hasLength(1));
    await pumpEventQueue();
    expect(states.last, isA<ModelReady>());
  });

  test('a hash that does not match discards the file and reports it', () async {
    serve = (_) async => http.StreamedResponse(Stream.value(utf8.encode('tampered')), 200);
    await manager.activate(model);
    await pumpEventQueue();
    expect(states.last, isA<ModelFailed>().having((s) => s.failure, 'failure', isA<IntegrityFailure>()));
    expect(fs.directory('/support/models').listSync(), isEmpty);
    expect(await manager.sizeOnDisk(model), 0);
  });

  test('the download reports its progress', () async {
    await manager.activate(model);
    final progress = states.whereType<ModelDownloading>().map((s) => s.progress).toList();
    expect(progress, [0, 10 / bytes.length, 1]);
  });

  test('after an error a new attempt downloads it', () async {
    serve = (_) async => http.StreamedResponse(const Stream.empty(), 503);
    await manager.activate(model);
    await pumpEventQueue();
    expect(states.last, isA<ModelFailed>().having((s) => s.failure, 'failure', isA<UnexpectedFailure>()));

    serve = (_) async => http.StreamedResponse(Stream.value(bytes), 200);
    await manager.download(model);
    await pumpEventQueue();
    expect(states.last, isA<ModelReady>());
    expect(requests, hasLength(2));
  });

  test('cancel aborts the download and removes the partial file', () async {
    final body = StreamController<List<int>>();
    serve = (r) async {
      unawaited(
        (r as http.Abortable).abortTrigger!.then((_) async {
          body.addError(http.RequestAbortedException(r.url));
          await body.close();
        }),
      );
      return http.StreamedResponse(body.stream, 200);
    };
    final downloading = manager.activate(model);
    body.add(bytes.sublist(0, 10));
    await pumpEventQueue();
    expect(states.last, isA<ModelDownloading>().having((s) => s.receivedBytes, 'receivedBytes', 10));
    expect(await manager.sizeOnDisk(model), 10);

    await manager.cancel(model);
    await downloading;
    expect(states.last, isA<ModelAbsent>());
    expect(fs.file('/support/models/m.litertlm.part').existsSync(), isFalse);
    expect(await manager.sizeOnDisk(model), 0);
  });

  test('a listener cancelling on the first state aborts the download', () async {
    final body = StreamController<List<int>>();
    serve = (r) async {
      unawaited(
        (r as http.Abortable).abortTrigger!.then((_) async {
          body.addError(http.RequestAbortedException(r.url));
          await body.close();
        }),
      );
      return http.StreamedResponse(body.stream, 200);
    };
    Future<void>? cancelling;
    manager.watch(model).listen((s) {
      if (s is ModelDownloading && cancelling == null) cancelling = manager.cancel(model);
    });
    final downloading = manager.download(model);
    await pumpEventQueue();
    if (!body.isClosed) body.add(bytes);
    await cancelling;
    await downloading;
    expect(states.last, isA<ModelAbsent>());
    expect(fs.file('/support/models/m.litertlm').existsSync(), isFalse);
  });

  test('cancel drops a pending confirmation', () async {
    network.wifi = false;
    await manager.activate(model);
    await manager.cancel(model);
    await pumpEventQueue();
    expect(states.last, isA<ModelAbsent>());
    expect(requests, isEmpty);
  });

  test('a listener cancelling on the confirmation sees it dropped, in order', () async {
    network.wifi = false;
    final seen = <ModelState>[];
    Future<void>? cancelling;
    manager.watch(model).listen((s) {
      seen.add(s);
      if (s is ModelAwaitingConfirmation) cancelling = manager.cancel(model);
    });
    await manager.activate(model);
    await pumpEventQueue();
    await cancelling;
    await pumpEventQueue();
    expect(seen, [isA<ModelAbsent>(), isA<ModelAwaitingConfirmation>(), isA<ModelAbsent>()]);
    expect(states.last, isA<ModelAbsent>());
    expect(await manager.watch(model).first, isA<ModelAbsent>());
    expect(requests, isEmpty);
  });

  test('the space on disk is exposed and deleting the model frees it', () async {
    await manager.activate(model);
    expect(await manager.sizeOnDisk(model), bytes.length);

    await manager.delete(model);
    expect(await manager.sizeOnDisk(model), 0);
    expect(fs.file('/support/models/m.litertlm').existsSync(), isFalse);
    expect(states.last, isA<ModelAbsent>());
  });

  test('a model already on disk is ready without downloading', () async {
    fs.file('/support/models/m.litertlm')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    final ready = await manager.watch(model).first;
    expect(ready, isA<ModelReady>());
    await manager.activate(model);
    expect(requests, isEmpty);
  });

  test('delete also removes the partial file a crash left behind', () async {
    fs.file('/support/models/m.litertlm.part')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes.sublist(0, 10));
    await manager.delete(model);
    expect(fs.file('/support/models/m.litertlm.part').existsSync(), isFalse);
    expect(await manager.sizeOnDisk(model), 0);
  });

  test('more bytes than the model stops the download', () async {
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () => cancelled = true);
    addTearDown(body.close);
    serve = (_) async => http.StreamedResponse(body.stream, 200);
    unawaited(manager.activate(model));
    body
      ..add(bytes)
      ..add([0]);
    await pumpEventQueue();
    expect(cancelled, isTrue);
    expect(states.last, isA<ModelFailed>().having((s) => s.failure, 'failure', isA<UnexpectedFailure>()));
    expect(await manager.sizeOnDisk(model), 0);
  });

  test('a declared length other than the model size fails before reading', () async {
    serve = (_) async => http.StreamedResponse(Stream.value(bytes), 200, contentLength: bytes.length + 1);
    await manager.activate(model);
    await pumpEventQueue();
    expect(states.last, isA<ModelFailed>().having((s) => s.failure, 'failure', isA<UnexpectedFailure>()));
    expect(await manager.sizeOnDisk(model), 0);
  });

  for (final (name, stop) in [
    ('cancel', (FileModelManager m) => m.cancel(model)),
    ('delete', (FileModelManager m) => m.delete(model)),
  ]) {
    test('$name while the activation checks the network starts nothing', () async {
      final slow = _SlowWifi();
      final gated = FileModelManager(MockClient((r) async => http.Response('', 200)), slow, fs.directory('/m'));
      final seen = <ModelState>[];
      gated.watch(model).listen(seen.add);
      final activating = gated.activate(model);
      await stop(gated);
      slow.answer.complete(true);
      await activating;
      expect(seen.last, isA<ModelAbsent>());
      expect(seen.whereType<ModelDownloading>(), isEmpty);
    });
  }

  test('an error response is drained before failing', () async {
    var listened = false;
    final body = StreamController<List<int>>(onListen: () => listened = true);
    addTearDown(body.close);
    serve = (_) async => http.StreamedResponse(body.stream, 503);
    await manager.activate(model);
    expect(listened, isTrue);
    await pumpEventQueue();
    expect(states.last, isA<ModelFailed>());
  });

  test('cancel during the final rename drops the model', () async {
    late FileModelManager renaming;
    renaming = FileModelManager(
      MockClient.streaming((_, _) async => http.StreamedResponse(Stream.value(bytes), 200)),
      network,
      _RenameHook(fs.directory('/support/models'), () => unawaited(renaming.cancel(model))),
    );
    final seen = <ModelState>[];
    renaming.watch(model).listen(seen.add);
    await renaming.activate(model);
    await pumpEventQueue();
    expect(seen.last, isA<ModelAbsent>());
    expect(fs.file('/support/models/m.litertlm').existsSync(), isFalse);
    expect(await renaming.sizeOnDisk(model), 0);
  });

  test('a server that stops sending fails after the idle timeout', () async {
    final stalled = FileModelManager(
      MockClient.streaming((_, _) async => http.StreamedResponse(StreamController<List<int>>().stream, 200)),
      network,
      fs.directory('/support/models'),
      idleTimeout: const Duration(milliseconds: 10),
    );
    final seen = <ModelState>[];
    stalled.watch(model).listen(seen.add);
    await stalled.activate(model);
    await pumpEventQueue();
    expect(seen.last, isA<ModelFailed>().having((s) => s.failure, 'failure', isA<UnexpectedFailure>()));
    expect(await stalled.sizeOnDisk(model), 0);
  });

  test('a server that never sends the headers fails after the idle timeout and aborts', () async {
    var aborted = false;
    final mute = FileModelManager(
      MockClient.streaming((r, _) {
        unawaited((r as http.Abortable).abortTrigger!.then((_) => aborted = true));
        return Completer<http.StreamedResponse>().future;
      }),
      network,
      fs.directory('/support/models'),
      idleTimeout: const Duration(milliseconds: 10),
    );
    final seen = <ModelState>[];
    mute.watch(model).listen(seen.add);
    await mute.activate(model);
    await pumpEventQueue();
    expect(seen.last, isA<ModelFailed>().having((s) => s.failure, 'failure', isA<UnexpectedFailure>()));
    expect(aborted, isTrue);
  });

  test('a download finished while the activation checks the network stays ready', () async {
    final slow = _SlowWifi();
    final gated = FileModelManager(MockClient((_) async => http.Response.bytes(bytes, 200)), slow, fs.directory('/m'));
    final seen = <ModelState>[];
    gated.watch(model).listen(seen.add);
    final activating = gated.activate(model);
    await gated.download(model);
    slow.answer.complete(false);
    await activating;
    expect(seen.last, isA<ModelReady>());
  });

  test('a partial file that cannot be opened leaves no response unread', () async {
    fs.directory('/support/models/m.litertlm.part').createSync(recursive: true);
    await manager.activate(model);
    await pumpEventQueue();
    expect(states.last, isA<ModelFailed>().having((s) => s.failure, 'failure', isA<UnexpectedFailure>()));
    // Opened before the request: no response is left holding the connection.
    expect(requests, isEmpty);
  });

  test('a second download during the first shares it', () async {
    final body = StreamController<List<int>>();
    serve = (_) async => http.StreamedResponse(body.stream, 200);
    final first = manager.download(model);
    await pumpEventQueue();
    final second = manager.download(model);
    body.add(bytes);
    await body.close();
    await Future.wait([first, second]);
    expect(requests, hasLength(1));
    await pumpEventQueue();
    expect(states.last, isA<ModelReady>());
  });

  test('delete during a download aborts it and frees the space', () async {
    final body = StreamController<List<int>>();
    serve = (r) async {
      unawaited(
        (r as http.Abortable).abortTrigger!.then((_) async {
          body.addError(http.RequestAbortedException(r.url));
          await body.close();
        }),
      );
      return http.StreamedResponse(body.stream, 200);
    };
    final downloading = manager.download(model);
    body.add(bytes.sublist(0, 10));
    await pumpEventQueue();
    await manager.delete(model);
    await downloading;
    expect(states.last, isA<ModelAbsent>());
    expect(await manager.sizeOnDisk(model), 0);
  });
}

/// Wi-Fi that answers only when the test says so.
class _SlowWifi() extends FakeConnectivity {
  final answer = Completer<bool>();

  @override
  Future<bool> isOnWifi() => answer.future;
}

/// The models folder, calling `onRename` when a file in it starts being renamed.
class _RenameHook(final Directory _dir, final void Function() _onRename) implements Directory {
  @override
  Future<Directory> create({bool recursive = false}) => _dir.create(recursive: recursive);

  @override
  File childFile(String basename) => _HookedFile(_dir.childFile(basename), _onRename);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HookedFile(final File _file, final void Function() _onRename) implements File {
  @override
  String get path => _file.path;

  @override
  bool existsSync() => _file.existsSync();

  @override
  FileStat statSync() => _file.statSync();

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) => _file.open(mode: mode);

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) => _file.delete(recursive: recursive);

  @override
  Future<File> rename(String newPath) {
    _onRename();
    return _file.rename(newPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
