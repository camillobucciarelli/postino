import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import '../domain/notification_action.dart';
import 'notification_payload.dart';

/// iOS and Android run a button in a background engine even while the app is open (#211): there the tap goes to the
/// app's isolate when it lives, so the lists show the Azione at once and one isolate writes; otherwise the background
/// one runs it.
const _portName = 'it.postino/notification_actions';

/// The app's isolate: takes the taps [relayToApp] hands over, until the returned port is closed.
ReceivePort listenForRelayedActions(void Function(NotificationActionTap tap) onAction) {
  final port = ReceivePort();
  IsolateNameServer.removePortNameMapping(_portName);
  IsolateNameServer.registerPortWithName(port.sendPort, _portName);
  port.listen((message) {
    if (message case [final String encoded, final SendPort ack]) {
      ack.send(true);
      if (decodeAction(encoded, null) case final tap?) onAction(tap);
    }
  });
  return port;
}

/// The background isolate: hands [tap] to the app's isolate; false when none answers within [wait] (the app is not
/// running, or its isolate is gone and left its name behind), and then the caller runs it.
Future<bool> relayToApp(NotificationActionTap tap, {Duration wait = const Duration(seconds: 2)}) async {
  final app = IsolateNameServer.lookupPortByName(_portName);
  if (app == null) return false;
  final ack = ReceivePort();
  try {
    app.send([encodeAction(tap), ack.sendPort]);
    return await ack.first.timeout(wait, onTimeout: () => false) == true;
  } finally {
    ack.close();
  }
}
