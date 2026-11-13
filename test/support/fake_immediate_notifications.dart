import 'dart:async';

import 'package:postino/core/domain/immediate_notifications.dart';

/// The Notifiche immediate's service (#214): records what is asked; [supported] false like a desktop until a test
/// makes it Android.
class FakeImmediateNotifications() implements ImmediateNotifications {
  @override
  bool supported = false;

  /// Whether the service runs.
  bool running = false;

  /// The notice of the last start.
  ListeningNotice? notice;

  /// Every start (true) and stop (false), in order.
  final calls = <bool>[];

  /// How many times the battery exemption was asked.
  int exemptionRequests = 0;

  /// While set, a start throws it: the OS refused.
  Exception? failure;

  /// While set, asking for the battery exemption throws it (no such dialog on the device).
  Exception? exemptionFailure;

  final _opened = StreamController<void>.broadcast();

  /// The fixed notification tapped.
  void tap() => _opened.add(null);

  @override
  Future<void> start(ListeningNotice notice) async {
    calls.add(true);
    if (failure case final f?) throw f;
    running = true;
    this.notice = notice;
  }

  @override
  Future<void> stop() async {
    calls.add(false);
    running = false;
  }

  @override
  Future<void> requestBatteryExemption() async {
    exemptionRequests++;
    if (exemptionFailure case final f?) throw f;
  }

  @override
  Stream<void> get opened => _opened.stream;
}
