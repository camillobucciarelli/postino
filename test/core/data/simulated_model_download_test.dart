// The pretend model download of #107: Wi-Fi starts at once, cellular asks first, failures can be retried.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/simulated_model_download.dart';
import 'package:postino/core/data/simulated_network_type.dart';
import 'package:postino/core/domain/model_download_state.dart';
import 'package:postino/core/domain/result.dart';

void main() {
  late SimulatedNetworkType network;
  late SimulatedModelDownload model;
  late List<ModelDownloadState> seen;
  setUp(() {
    network = SimulatedNetworkType();
    model = SimulatedModelDownload(network)
      ..stepDelay = Duration.zero
      ..steps = 4;
    seen = [];
    final sub = model.watch().listen(seen.add);
    addTearDown(sub.cancel);
  });

  List<Type> kinds() => [for (final s in seen) s.runtimeType];

  test('absent until activated', () async {
    await pumpEventQueue();
    expect(model.state, isA<ModelDownloadAbsent>());
    expect(kinds(), [ModelDownloadAbsent]);
  });

  test('on Wi-Fi the first activation downloads at once: preparing, chunks, ready', () async {
    await model.activate();
    await pumpEventQueue();
    expect(kinds(), [
      ModelDownloadAbsent,
      ModelDownloadPreparing,
      ...List.filled(4, ModelDownloadInProgress),
      ModelDownloadReady,
    ]);
    final last = seen[5] as ModelDownloadInProgress;
    expect((last.receivedBytes, last.totalBytes), (232500000, SimulatedModelDownload.sizeBytes));
  });

  test('on cellular it waits for confirmation; «Scarica ora» downloads', () async {
    network.onWifi = false;
    await model.activate();
    expect(model.state, isA<ModelDownloadAwaitingConfirmation>());
    expect((model.state as ModelDownloadAwaitingConfirmation).sizeBytes, 310000000);

    await model.download();
    expect(model.state, isA<ModelDownloadReady>());
  });

  test('«Aspetta il Wi-Fi» waits; «Scarica ora» from there downloads', () async {
    network.onWifi = false;
    await model.activate();
    model.waitForWifi();
    expect(model.state, isA<ModelDownloadWaitingForWifi>());

    await model.download();
    expect(model.state, isA<ModelDownloadReady>());
  });

  test('a failure stops halfway with its reason; «Riprova» downloads again', () async {
    model.failNext = true;
    await model.activate();
    expect((model.state as ModelDownloadFailed).failure, isA<OfflineFailure>());

    await model.download();
    expect(model.state, isA<ModelDownloadReady>());
  });

  test('activating again, or waiting for Wi-Fi outside the confirmation, changes nothing', () async {
    await model.activate();
    model.waitForWifi();
    await model.activate();
    await model.download();
    expect(model.state, isA<ModelDownloadReady>());
    await pumpEventQueue();
    expect(kinds().where((k) => k == ModelDownloadReady), hasLength(1));
  });
}
