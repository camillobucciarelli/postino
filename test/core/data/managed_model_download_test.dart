// Il download del modello come lo segue la UI (#135), sopra un gestore dei modelli finto.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/managed_model_download.dart';
import 'package:postino/core/domain/embedding_models.dart';
import 'package:postino/core/domain/model_download_state.dart';
import 'package:postino/core/domain/model_state.dart';
import 'package:postino/core/domain/result.dart';

import '../../support/fake_model_manager.dart';

void main() {
  final model = embeddingGemmaLiteRt;
  late FakeModelManager manager;
  late ManagedModelDownload download;
  late List<ModelDownloadState> seen;
  setUp(() {
    manager = FakeModelManager();
    download = ManagedModelDownload(manager, model);
    seen = [];
    final sub = download.watch().listen(seen.add);
    addTearDown(sub.cancel);
  });

  List<Type> kinds() => [for (final s in seen) s.runtimeType];

  test('absent until activated', () async {
    await pumpEventQueue();
    expect(download.state, isA<ModelDownloadAbsent>());
    expect(kinds(), [ModelDownloadAbsent]);
  });

  test('a model already on the device is ready from the start', () async {
    manager.emit(model, const ModelReady('/models/x'));
    final again = ManagedModelDownload(manager, model);
    await pumpEventQueue();
    expect(again.state, isA<ModelDownloadReady>());
  });

  test('on Wi-Fi the first activation prepares, downloads the chosen model and is ready', () async {
    await download.activate();
    await pumpEventQueue();
    expect(kinds(), [
      ModelDownloadAbsent,
      ModelDownloadPreparing,
      ModelDownloadInProgress,
      ModelDownloadInProgress,
      ModelDownloadReady,
    ]);
    final half = seen[3] as ModelDownloadInProgress;
    expect((half.receivedBytes, half.totalBytes), (model.sizeBytes ~/ 2, model.sizeBytes));
    expect(manager.calls, ['activate ${model.id}']);
  });

  test('on cellular it waits for confirmation with the size; «Scarica ora» downloads', () async {
    manager.onWifi = false;
    await download.activate();
    expect((download.state as ModelDownloadAwaitingConfirmation).sizeBytes, model.sizeBytes);
    await download.download();
    expect(download.state, isA<ModelDownloadReady>());
  });

  test('«Aspetta il Wi-Fi» waits; «Scarica ora» from there downloads', () async {
    manager.onWifi = false;
    await download.activate();
    download.waitForWifi();
    expect((download.state as ModelDownloadWaitingForWifi).sizeBytes, model.sizeBytes);
    await download.download();
    expect(download.state, isA<ModelDownloadReady>());
  });

  test('waiting for Wi-Fi ends with that confirmation: a cancel, then a new activation, asks again', () async {
    manager.onWifi = false;
    await download.activate();
    download.waitForWifi();
    await manager.cancel(model);
    expect(download.state, isA<ModelDownloadAbsent>());
    await download.activate();
    expect(download.state, isA<ModelDownloadAwaitingConfirmation>());
  });

  test('a failure keeps its reason; «Riprova» downloads again', () async {
    manager.failNext = true;
    await download.activate();
    expect((download.state as ModelDownloadFailed).failure, isA<OfflineFailure>());
    await download.download();
    expect(download.state, isA<ModelDownloadReady>());
  });

  test('activating again, downloading when ready or waiting outside the confirmation change nothing', () async {
    await download.activate();
    download.waitForWifi();
    await download.activate();
    await download.download();
    expect(download.state, isA<ModelDownloadReady>());
    await pumpEventQueue();
    expect(kinds().where((k) => k == ModelDownloadReady), hasLength(1));
    expect(manager.calls, ['activate ${model.id}']);
  });

  test('the model deleted goes back to absent', () async {
    await download.activate();
    await manager.delete(model);
    expect(download.state, isA<ModelDownloadAbsent>());
  });
}
