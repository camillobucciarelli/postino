// The on-device model manager (#108), with the network and the file system in memory.
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
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
    expect(states.last, isA<ModelReady>().having((s) => s.path, 'path', '/support/models/m.litertlm'));
    expect(fs.file('/support/models/m.litertlm').readAsBytesSync(), bytes);
    expect(fs.file('/support/models/m.litertlm.part').existsSync(), isFalse);
  });

  test('off Wi-Fi it waits for the confirmation, showing the size', () async {
    network.wifi = false;
    await manager.activate(model);
    expect(requests, isEmpty);
    expect(states.last, isA<ModelAwaitingConfirmation>().having((s) => s.sizeBytes, 'sizeBytes', bytes.length));

    await manager.download(model);
    expect(requests, hasLength(1));
    expect(states.last, isA<ModelReady>());
  });

  test('a hash that does not match discards the file and reports it', () async {
    serve = (_) async => http.StreamedResponse(Stream.value(utf8.encode('tampered')), 200);
    await manager.activate(model);
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
    expect(states.last, isA<ModelFailed>().having((s) => s.failure, 'failure', isA<UnexpectedFailure>()));

    serve = (_) async => http.StreamedResponse(Stream.value(bytes), 200);
    await manager.download(model);
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

  test('cancel drops a pending confirmation', () async {
    network.wifi = false;
    await manager.activate(model);
    await manager.cancel(model);
    expect(states.last, isA<ModelAbsent>());
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
}
