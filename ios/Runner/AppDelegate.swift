import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Background tasks begun for the outbox (#36), by identifier; ended once or at expiration.
  private var sendTasks = Set<Int>()
  private var backgroundChannel: FlutterMethodChannel?
  private var notificationSettingsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications (#39): without it a tap that launches the app never reaches the plugin.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // A notification's button runs in a background engine (#211): it needs the plugins too (the database, the
    // keychain, the network).
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // #211: «Consenti» in the Impostazioni del dispositivo, once iOS no longer asks.
    let settings = FlutterMethodChannel(
      name: "it.postino/notification_settings",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    settings.setMethodCallHandler { call, result in
      guard call.method == "open" else { return result(FlutterMethodNotImplemented) }
      if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(nil)
    }
    notificationSettingsChannel = settings
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
  }

  private func endSendTask(_ raw: Int) {
    guard sendTasks.remove(raw) != nil else { return }
    UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: raw))
  }
}
