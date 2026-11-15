import Flutter
import UIKit
import flutter_local_notifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Background tasks begun for the outbox (#36), by identifier; ended once or at expiration.
  private var sendTasks = Set<Int>()
  private var backgroundChannel: FlutterMethodChannel?
  private var screenGuardChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications (#39): without it a tap that launches the app never reaches the plugin.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    // The sync in background (#213): the BGAppRefreshTask of workmanager runs Dart in an engine of its own, which needs
    // the plugins, and its identifier (Info.plist) registered before the launch ends. Dart schedules it.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "postino.sync", earliestBeginInSeconds: NSNumber(value: 15 * 60))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // A notification's button runs in a background engine (#211): it needs the plugins too (the database, the
    // keychain, the network).
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "it.postino/background",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "beginBackgroundTask":
        var id = UIBackgroundTaskIdentifier.invalid
        id = UIApplication.shared.beginBackgroundTask(withName: "postino.send") {
          self?.endSendTask(id.rawValue)
        }
        if id != .invalid { self?.sendTasks.insert(id.rawValue) }
        result(id.rawValue)
      case "endBackgroundTask":
        if let raw = call.arguments as? Int { self?.endSendTask(raw) }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    backgroundChannel = channel

    // The codice di abbinamento (ADR 0019): screenshots cannot be stopped on iOS, so Dart hides it while the screen is
    // recorded or mirrored. protect(bool) answers whether it is now; "captured"(bool) at every change.
    let guardChannel = FlutterMethodChannel(
      name: "it.postino/screen_guard",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    guardChannel.setMethodCallHandler { call, result in
      guard call.method == "protect" else { return result(FlutterMethodNotImplemented) }
      result(UIScreen.main.isCaptured)
    }
    NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main
    ) { [weak self] note in
      let captured = (note.object as? UIScreen)?.isCaptured ?? UIScreen.main.isCaptured
      self?.screenGuardChannel?.invokeMethod("captured", arguments: captured)
    }
    screenGuardChannel = guardChannel
  }

  private func endSendTask(_ raw: Int) {
    guard sendTasks.remove(raw) != nil else { return }
    UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: raw))
  }
}
