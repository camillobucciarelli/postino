// The «Automatica» switch (#107): saved, and the first activation starts the model download.

import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/auto_labels_store.dart';
import 'package:postino/core/data/postino_database.dart';
import 'package:postino/core/data/simulated_model_download.dart';
import 'package:postino/core/data/simulated_network_type.dart';
import 'package:postino/core/domain/model_download_state.dart';
import 'package:postino/features/impostazioni/domain/auto_label_switch_use_case.dart';

import '../../../support/fake_platform.dart';

void main() {
  late PostinoDatabase db;
  late AutoLabelsStore labels;
  late SimulatedNetworkType network;
  late SimulatedModelDownload model;
  late AutoLabelSwitchUseCase useCase;
  setUp(() {
    db = PostinoDatabase.inMemory();
    labels = AutoLabelsStore(db, FakeClock(DateTime.utc(2026, 11, 5)));
    network = SimulatedNetworkType();
    model = SimulatedModelDownload(network)..stepDelay = Duration.zero;
    useCase = AutoLabelSwitchUseCase(labels, model);
  });
  tearDown(() => db.close());

  test('turning on saves it and, on Wi-Fi, downloads the model', () async {
    await useCase.setAutomatic('a1', 'L1', automatic: true);
    expect(await labels.watch('a1').first, {
      'L1': (automatic: true, description: null, activatedAt: DateTime.utc(2026, 11, 5).millisecondsSinceEpoch),
    });
    await pumpEventQueue();
    expect(model.state, isA<ModelDownloadReady>());
  });

  test('on cellular the first activation asks for confirmation', () async {
    network.onWifi = false;
    await useCase.setAutomatic('a1', 'L1', automatic: true);
    await pumpEventQueue();
    expect(model.state, isA<ModelDownloadAwaitingConfirmation>());
  });

  test('turning off saves it and leaves the model alone', () async {
    await useCase.setAutomatic('a1', 'L1', automatic: false);
    await pumpEventQueue();
    expect(model.state, isA<ModelDownloadAbsent>());
  });
}
